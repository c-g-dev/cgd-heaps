package cgd.ui;

import heaps.coroutine.Future;

enum SuperTextTypewriterParagraphBreak {
    WaitForAdvance;
    AutoAdvance;
}

enum SuperTextTypewriterOnFrameState {
    Writing;
    AllLinesAllocated;
    DeallocatingLines;
    ParagraphBreak;
    NoMoreParagraphs;
}

enum SuperTextTypewriterRequest {
    Wait;
    Advance; //if all lines are allocated, start deallocating lines. if on paragraph break, go to next paragraph or finish.
    AutoFill; //if writing, auto fill all available line space or write full paragraph, whichever is shorter. otherwise, do nothing.
    Pause; //pause writing.
    Resume; //resume writing.
    Finish;
}

enum SuperTextTypewriterDeallocateLinesEffect {
    SlideLinesUp(speed:Float); //slide all lines up and deallocate the top line once it moves out of the designated typewriter rendering space
    Clear; //deallocate all lines and start the next pending line at the top
    Custom(callback: SuperText -> Future); //custom effect to run when deallocating lines.
}

class SuperTextTypewriter {

    var target:SuperText;
    var speed:Float; //speed in characters per second
    var maxLines: Int; //max lines to show. -1 for infinite
    var paragraphBreakMode: SuperTextTypewriterParagraphBreak;
    var controller: SuperTextTypewriterOnFrameState -> SuperTextTypewriterRequest; //called every frame. SuperTextTypewriterOnFrameState is reported by the typewriter. SuperTextTypewriterRequest is the response from the calling code.
    var deallocateLinesEffect: SuperTextTypewriterDeallocateLinesEffect;

    var state:SuperTextTypewriterOnFrameState = Writing;
    var started:Bool = false;
    var done:Bool = false;
    var paused:Bool = false;
    var completion:Future;

    var sourceHtml:String = "<p></p>";
    var pageHtml:String = "<p></p>";
    var renderedHtml:String = "<p></p>";

    var totalVisibleChars:Int = 0;
    var progress:Int = 0;
    var pageStart:Int = 0;
    var carry:Float = 0.;

    var paragraphEnds:Array<Int> = [];
    var paragraphCursor:Int = 0;

    var sourceVisibleText:String = "";

    var customDeallocateFuture:Future;
    var isSliding:Bool = false;
    var slideSpeed:Float = 0.;
    var slideDistance:Float = 0.;
    var slideMoved:Float = 0.;
    var baseY:Float = 0.;
    var deallocateChars:Int = 0;
    var wordWrapLookaheadEnd:Int = -1;
    var charSpeedMap:Array<Float> = [];

    public function new(
        target:SuperText,
        ?speed = 30.,
        ?maxLines = -1,
        ?paragraphBreakMode = WaitForAdvance,
        ?controller:SuperTextTypewriterOnFrameState -> SuperTextTypewriterRequest,
        ?deallocateLinesEffect:SuperTextTypewriterDeallocateLinesEffect = Clear
    ) {
        if( target == null ) throw "SuperTextTypewriter requires a non-null SuperText target.";
        if( speed <= 0 ) throw "SuperTextTypewriter speed must be > 0.";
        if( maxLines == 0 || maxLines < -1 ) throw "SuperTextTypewriter maxLines must be -1 or > 0.";
        this.target = target;
        this.speed = speed;
        this.maxLines = maxLines;
        this.paragraphBreakMode = paragraphBreakMode == null ? WaitForAdvance : paragraphBreakMode;
        this.controller = controller == null ? defaultController : controller;
        this.deallocateLinesEffect = deallocateLinesEffect == null ? Clear : deallocateLinesEffect;
    }

    function defaultController(current:SuperTextTypewriterOnFrameState):SuperTextTypewriterRequest {
        return switch( current ) {
        case NoMoreParagraphs: Finish;
        default: Wait;
        }
    }

    public function start(): Future {
        if( started && completion != null && !completion.isComplete ) return completion;
        completion = new Future();
        started = true;
        done = false;
        paused = false;
        carry = 0.;
        state = Writing;
        customDeallocateFuture = null;
        isSliding = false;
        slideDistance = 0.;
        slideMoved = 0.;
        slideSpeed = 0.;
        deallocateChars = 0;
        baseY = target.y;
        sourceHtml = normalizeHtml(target.htmlText);
        pageStart = 0;
        progress = 0;
        paragraphEnds = buildParagraphEnds(sourceHtml);
        paragraphCursor = 0;
        totalVisibleChars = visibleLengthForHtml(sourceHtml);
        sourceVisibleText = extractVisibleText(sourceHtml);
        charSpeedMap = buildCharSpeedMap(sourceHtml);
        pageHtml = sourceHtml;
        wordWrapLookaheadEnd = -1;
        renderedHtml = "<p></p>";
        renderHtml(renderedHtml);
        target.__registerTypewriter(this);
        if( totalVisibleChars <= 0 ) state = NoMoreParagraphs;
        return completion;
    } // starts the typewriting effect for the entire context of the SuperText object. Future completes once all paragraphs have been written and the Finished request has been sent by the controller.

    function normalizeHtml(html:String):String {
        if( html == null ) return "<p></p>";
        if( StringTools.trim(html) == "" ) return "<p></p>";
        return html;
    }

    function buildParagraphEnds(html:String):Array<Int> {
        var ends:Array<Int> = [];
        var doc = Xml.parse(html);
        buildParagraphEndsFromNode(doc, ends, 0);
        if( ends.length == 0 ) ends.push(visibleLengthForHtml(html));
        return ends;
    }

    function buildParagraphEndsFromNode(node:Xml, ends:Array<Int>, running:Int):Int {
        for( child in node ) {
            if( child.nodeType == Xml.PCData ) {
                if( StringTools.trim(child.nodeValue) == "" ) continue;
                running += visibleLengthForNode(child);
                continue;
            }
            if( child.nodeType != Xml.Element ) continue;
            if( child.nodeName.toLowerCase() == "p" ) {
                if( containsNestedParagraphs(child) ) {
                    running = buildParagraphEndsFromNode(child, ends, running);
                } else {
                    var childLen = visibleLengthForHtml(child.toString());
                    if( childLen <= 0 ) continue;
                    running += childLen;
                    ends.push(running);
                }
            } else {
                running += visibleLengthForNode(child);
            }
        }
        return running;
    }

    function containsNestedParagraphs(node:Xml):Bool {
        for( child in node ) {
            if( child.nodeType == Xml.Element && child.nodeName.toLowerCase() == "p" ) return true;
        }
        return false;
    }

    inline function currentState():SuperTextTypewriterOnFrameState {
        return state;
    }

    @:allow(cgd.ui.SuperText)
    function __onFrame(dt:Float):Void {
        if( !started || done ) return;
        if( dt <= 0 ) return;

        updateDeallocation(dt);

        var request = controller(currentState());
        applyRequest(request);

        if( done ) return;
        if( state == DeallocatingLines ) return;
        if( paused ) return;

        switch( state ) {
        case Writing:
            writeBySpeed(dt);
        case ParagraphBreak:
            if( paragraphBreakMode == AutoAdvance ) advanceFromParagraphBreak();
        case AllLinesAllocated, NoMoreParagraphs:
        case DeallocatingLines:
        }
    }

    function applyRequest(request:SuperTextTypewriterRequest):Void {
        switch( request ) {
        case Wait:
        case Pause:
            paused = true;
        case Resume:
            paused = false;
        case Advance:
            switch( state ) {
            case AllLinesAllocated:
                beginDeallocation();
            case ParagraphBreak:
                advanceFromParagraphBreak();
            case Writing, DeallocatingLines, NoMoreParagraphs:
            }
        case AutoFill:
            if( state == Writing && !paused ) autoFill();
        case Finish:
            if( state == NoMoreParagraphs ) complete();
        }
    }

    function writeBySpeed(dt:Float):Void {
        var charSpeed = getCharSpeed(progress);
        carry += charSpeed * dt;
        var steps = Std.int(carry);
        if( steps <= 0 ) return;
        carry -= steps;
        for( _ in 0...steps ) {
            if( !revealOneCharacter() ) break;
        }
    }

    function autoFill():Void {
        while( state == Writing && revealOneCharacter() ) {
        }
    }

    function revealOneCharacter():Bool {
        if( progress >= totalVisibleChars ) {
            state = ParagraphBreak;
            return false;
        }

        if( wordWrapLookaheadEnd < 0 && isAtWordStart(progress) ) {
            var wordEnd = findWordEnd(progress);
            if( wordEnd > progress ) {
                var wrappedLineCount = wordWrapLineCount(wordEnd);
                if( wrappedLineCount > 0 ) {
                    if( maxLines > -1 && wrappedLineCount > maxLines ) {
                        state = AllLinesAllocated;
                        return false;
                    }
                    wordWrapLookaheadEnd = wordEnd;
                }
            }
        }

        var nextProgress = progress + 1;
        renderProgress(nextProgress);

        if( maxLines > -1 && currentLineCount() > maxLines ) {
            var wordBoundary = findWordBoundaryBefore(progress);
            if( wordBoundary < progress ) progress = wordBoundary;
            wordWrapLookaheadEnd = -1;
            renderProgress(progress);
            state = AllLinesAllocated;
            return false;
        }

        progress = nextProgress;

        if( wordWrapLookaheadEnd > 0 && progress >= wordWrapLookaheadEnd )
            wordWrapLookaheadEnd = -1;

        if( reachedParagraphBoundary() ) {
            wordWrapLookaheadEnd = -1;
            state = ParagraphBreak;
            paragraphCursor++;
            return false;
        }
        return true;
    }

    function reachedParagraphBoundary():Bool {
        if( paragraphCursor >= paragraphEnds.length ) return false;
        return progress >= paragraphEnds[paragraphCursor];
    }

    function advanceFromParagraphBreak():Void {
        if( paragraphCursor >= paragraphEnds.length ) {
            state = NoMoreParagraphs;
        } else {
            pageStart = progress;
            pageHtml = sliceFromProgress(sourceHtml, pageStart);
            wordWrapLookaheadEnd = -1;
            renderedHtml = "<p></p>";
            renderHtml(renderedHtml);
            state = Writing;
        }
    }

    function renderProgress(globalProgress:Int):Void {
        var localProgress = globalProgress - pageStart;
        if( localProgress < 0 ) throw "SuperTextTypewriter internal progress moved before page start.";

        if( wordWrapLookaheadEnd > 0 && globalProgress < wordWrapLookaheadEnd ) {
            var localWordEnd = wordWrapLookaheadEnd - pageStart;
            var html = target.getTextProgress(pageHtml, localWordEnd);
            renderedHtml = normalizeHtml(html);
            @:privateAccess target.typewriterVisibleChars = localProgress;
            target.htmlText = renderedHtml;
            @:privateAccess target.needsRebuild = true;
            @:privateAccess target.flushTextLayout();
            @:privateAccess target.typewriterVisibleChars = -1;
            return;
        }

        var html = target.getTextProgress(pageHtml, localProgress);
        renderedHtml = normalizeHtml(html);
        renderHtml(renderedHtml);
    }

    function beginDeallocation():Void {
        wordWrapLookaheadEnd = -1;
        state = DeallocatingLines;
        deallocateChars = computeDeallocateChars();
        if( deallocateChars <= 0 ) {
            deallocateChars = 0;
            finalizeDeallocation();
            return;
        }
        switch( deallocateLinesEffect ) {
        case Clear:
            finalizeDeallocation();
        case SlideLinesUp(speed):
            if( speed <= 0 ) throw "SuperTextTypewriter SlideLinesUp speed must be > 0.";
            isSliding = true;
            slideSpeed = speed;
            slideMoved = 0.;
            baseY = target.y;
            slideDistance = computeSlideDistance(deallocateChars);
            if( slideDistance <= 0 ) {
                isSliding = false;
                finalizeDeallocation();
            }
        case Custom(callback):
            if( callback == null ) throw "SuperTextTypewriter Custom deallocate callback is null.";
            customDeallocateFuture = callback(target);
            if( customDeallocateFuture == null )
                throw "SuperTextTypewriter Custom deallocate callback returned null Future.";
        }
    }

    function updateDeallocation(dt:Float):Void {
        if( state != DeallocatingLines ) return;
        if( isSliding ) {
            slideMoved += slideSpeed * dt;
            if( slideMoved >= slideDistance ) {
                target.y = baseY;
                isSliding = false;
                finalizeDeallocation();
            } else {
                target.y = baseY - slideMoved;
            }
            return;
        }
        if( customDeallocateFuture != null && customDeallocateFuture.isComplete ) {
            customDeallocateFuture = null;
            finalizeDeallocation();
        }
    }

    function finalizeDeallocation():Void {
        wordWrapLookaheadEnd = -1;
        pageStart += deallocateChars;
        if( pageStart > progress ) pageStart = progress;
        pageHtml = sliceFromProgress(sourceHtml, pageStart);
        renderProgress(progress);
        deallocateChars = 0;
        state = Writing;
    }

    function complete():Void {
        if( done ) return;
        done = true;
        started = false;
        paused = false;
        isSliding = false;
        wordWrapLookaheadEnd = -1;
        customDeallocateFuture = null;
        target.y = baseY;
        target.__unregisterTypewriter(this);
        completion.resolve(this);
    }

    function renderHtml(html:String):Void {
        target.htmlText = html == null || StringTools.trim(html) == "" ? "<p></p>" : html;
        @:privateAccess target.flushTextLayout();
    }

    inline function currentLineCount():Int {
        return @:privateAccess target.sizePos + 1;
    }

    function visibleLengthForHtml(html:String):Int {
        var normalized = html == null || StringTools.trim(html) == "" ? "<p></p>" : html;
        var doc = @:privateAccess target.parseText(normalized);
        return visibleLengthForNode(doc);
    }

    function sliceFromProgress(html:String, progress:Int):String {
        var normalized = html == null || StringTools.trim(html) == "" ? "<p></p>" : html;
        if( progress <= 0 ) return normalized;
        var total = visibleLengthForHtml(normalized);
        if( progress >= total ) return "<p></p>";

        var doc = @:privateAccess target.parseText(normalized);
        trimNodeFromStart(doc, progress);
        var sliced = doc.toString();
        if( sliced == null || StringTools.trim(sliced) == "" ) return "<p></p>";
        return sliced;
    }

    function visibleLengthForNode(node:Xml):Int {
        switch( node.nodeType ) {
        case Document, Element:
            var total = 0;
            for( child in node )
                total += visibleLengthForNode(child);
            return total;
        case PCData, CData:
            if( node.nodeValue == null || node.nodeValue == "" ) return 0;
            return @:privateAccess target.htmlToText(node.nodeValue).length;
        default:
            return 0;
        }
    }

    function computeDeallocateChars():Int {
        var visibleChars = progress - pageStart;
        if( visibleChars <= 0 ) return 0;

        renderHtml(renderedHtml);
        var lineBreaks = @:privateAccess target.renderLineBreaks;
        if( lineBreaks.length == 0 ) return visibleChars;

        var charsToRemove = lineBreaks[0];
        if( charsToRemove <= 0 ) return visibleChars;
        if( charsToRemove > visibleChars ) charsToRemove = visibleChars;

        while( charsToRemove < visibleChars ) {
            var idx = pageStart + charsToRemove;
            if( idx >= sourceVisibleText.length ) break;
            var ch = StringTools.fastCodeAt(sourceVisibleText, idx);
            if( ch != ' '.code && ch != '\n'.code && ch != '\t'.code ) break;
            charsToRemove++;
        }

        return charsToRemove;
    }

    function htmlAfterRemovingPrefix(visibleChars:Int, charsToRemove:Int):String {
        if( charsToRemove <= 0 ) return renderedHtml;
        if( visibleChars <= 0 || charsToRemove >= visibleChars ) return "<p></p>";

        var nextPageStart = pageStart + charsToRemove;
        var nextPageHtml = sliceFromProgress(sourceHtml, nextPageStart);
        var remainingVisible = visibleChars - charsToRemove;
        if( remainingVisible <= 0 ) return "<p></p>";
        return normalizeHtml(target.getTextProgress(nextPageHtml, remainingVisible));
    }

    function computeSlideDistance(charsToRemove:Int):Float {
        if( charsToRemove <= 0 ) return 0.;

        var visibleChars = progress - pageStart;
        if( visibleChars <= 0 ) return 0.;
        if( charsToRemove > visibleChars ) charsToRemove = visibleChars;

        var previousHtml = renderedHtml;
        renderHtml(previousHtml);
        var beforeSize = target.getSize();
        var beforeHeight = beforeSize.yMax - beforeSize.yMin;

        var afterHtml = htmlAfterRemovingPrefix(visibleChars, charsToRemove);
        renderHtml(afterHtml);
        var afterSize = target.getSize();
        var afterHeight = afterSize.yMax - afterSize.yMin;

        renderedHtml = previousHtml;
        renderHtml(previousHtml);

        var distance = beforeHeight - afterHeight;
        if( distance > 0 ) return distance;

        var lines = currentLineCount();
        if( lines <= 1 ) return beforeHeight;
        return beforeHeight / lines;
    }

    function trimNodeFromStart(node:Xml, remaining:Int):Int {
        if( remaining <= 0 ) return 0;
        switch( node.nodeType ) {
        case Document, Element:
            var children = [for( child in node ) child];
            for( child in children ) {
                if( remaining <= 0 ) break;
                var visibleChars = visibleLengthForNode(child);
                if( visibleChars <= 0 ) {
                    node.removeChild(child);
                    continue;
                }
                if( remaining >= visibleChars ) {
                    remaining -= visibleChars;
                    node.removeChild(child);
                    continue;
                }
                remaining = trimNodeFromStart(child, remaining);
                break;
            }
            return remaining;
        case PCData, CData:
            var normalized = @:privateAccess target.htmlToText(node.nodeValue);
            if( remaining >= normalized.length ) {
                node.nodeValue = "";
                return remaining - normalized.length;
            }
            node.nodeValue = normalized.substr(remaining);
            return 0;
        default:
            return remaining;
        }
    }

    function extractVisibleText(html:String):String {
        var normalized = html == null || StringTools.trim(html) == "" ? "<p></p>" : html;
        var doc = @:privateAccess target.parseText(normalized);
        var buf = new StringBuf();
        collectVisibleText(doc, buf);
        return buf.toString();
    }

    function collectVisibleText(node:Xml, buf:StringBuf):Void {
        switch( node.nodeType ) {
        case Document, Element:
            for( child in node )
                collectVisibleText(child, buf);
        case PCData, CData:
            if( node.nodeValue != null && node.nodeValue != "" )
                buf.add(@:privateAccess target.htmlToText(node.nodeValue));
        default:
        }
    }

    function isAtWordStart(pos:Int):Bool {
        if( pos < 0 || pos >= sourceVisibleText.length ) return false;
        var ch = StringTools.fastCodeAt(sourceVisibleText, pos);
        if( ch == ' '.code || ch == '\n'.code || ch == '\t'.code ) return false;
        if( pos == 0 ) return true;
        var prevCh = StringTools.fastCodeAt(sourceVisibleText, pos - 1);
        return prevCh == ' '.code || prevCh == '\n'.code || prevCh == '\t'.code;
    }

    function findWordEnd(pos:Int):Int {
        var limit = totalVisibleChars;
        if( paragraphCursor < paragraphEnds.length ) {
            var paragraphEnd = paragraphEnds[paragraphCursor];
            if( paragraphEnd < limit ) limit = paragraphEnd;
        }
        var i = pos;
        while( i < limit ) {
            var ch = StringTools.fastCodeAt(sourceVisibleText, i);
            if( ch == ' '.code || ch == '\n'.code || ch == '\t'.code ) break;
            i++;
        }
        return i;
    }

    /** Returns the line count after word-wrap if the word would wrap, or -1 if it wouldn't. */
    function wordWrapLineCount(wordEnd:Int):Int {
        if( @:privateAccess target.realMaxWidth < 0 ) return -1;
        var lineCountBefore = currentLineCount();
        var localWordEnd = wordEnd - pageStart;
        var html = target.getTextProgress(pageHtml, localWordEnd);
        renderHtml(normalizeHtml(html));
        var lineCountAfter = currentLineCount();
        renderHtml(renderedHtml);
        return lineCountAfter > lineCountBefore ? lineCountAfter : -1;
    }

    function findWordBoundaryBefore(pos:Int):Int {
        var lowerBound = pageStart;
        var paragraphStart = paragraphCursor == 0 ? 0 : paragraphEnds[paragraphCursor - 1];
        if( paragraphStart > lowerBound ) lowerBound = paragraphStart;
        if( pos <= lowerBound ) return pos;
        var i = pos - 1;
        if( i >= 0 && i < sourceVisibleText.length ) {
            var ch = StringTools.fastCodeAt(sourceVisibleText, i);
            if( ch == ' '.code || ch == '\n'.code || ch == '\t'.code ) return pos;
        }
        i--;
        while( i >= lowerBound ) {
            var ch = StringTools.fastCodeAt(sourceVisibleText, i);
            if( ch == ' '.code || ch == '\n'.code || ch == '\t'.code ) return i + 1;
            i--;
        }
        return pos;
    }
    
    function getCharSpeed(charIndex:Int):Float {
        if( charIndex >= 0 && charIndex < charSpeedMap.length ) {
            var mapped = charSpeedMap[charIndex];
            if( mapped > 0 ) return mapped;
        }
        return speed;
    }

    function buildCharSpeedMap(html:String):Array<Float> {
        var normalized = html == null || StringTools.trim(html) == "" ? "<p></p>" : html;
        var doc = @:privateAccess target.parseText(normalized);
        var map:Array<Float> = [];
        var speedStack:Array<Float> = [];
        buildCharSpeedMapFromNode(doc, map, speedStack);
        return map;
    }

    function buildCharSpeedMapFromNode(node:Xml, map:Array<Float>, speedStack:Array<Float>):Void {
        switch( node.nodeType ) {
        case Document:
            for( child in node )
                buildCharSpeedMapFromNode(child, map, speedStack);
        case Element:
            var pushedSpeed = false;
            var nodeName = node.nodeName.toLowerCase();
            if( nodeName == "speed" ) {
                var val = node.get("val");
                if( val != null ) {
                    speedStack.push(Std.parseFloat(val));
                    pushedSpeed = true;
                }
            }
            if( !pushedSpeed && node.exists("speed") ) {
                speedStack.push(Std.parseFloat(node.get("speed")));
                pushedSpeed = true;
            }
            for( child in node )
                buildCharSpeedMapFromNode(child, map, speedStack);
            if( pushedSpeed )
                speedStack.pop();
        case PCData, CData:
            if( node.nodeValue != null && node.nodeValue != "" ) {
                var text = @:privateAccess target.htmlToText(node.nodeValue);
                var currentSpeed = speedStack.length > 0 ? speedStack[speedStack.length - 1] : 0.;
                for( _ in 0...text.length )
                    map.push(currentSpeed);
            }
        default:
        }
    }

}