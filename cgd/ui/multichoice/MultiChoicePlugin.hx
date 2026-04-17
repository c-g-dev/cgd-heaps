package cgd.ui.multichoice;

import cgd.ui.multichoice.MultiChoiceStyles.MultiChoiceOption;

class MultiChoicePlugin {

    var multiChoice:MultiChoiceBox;

    public function new(multiChoice:MultiChoiceBox) {
        if( multiChoice == null ) throw "MultiChoicePlugin requires a non-null multiChoice.";
        this.multiChoice = multiChoice;
    }

    public function onAttach():Void {}

    public function onDetach():Void {}

    public function onChoicesChanged(options:Array<MultiChoiceOption>):Void {}

    public function onSelectionChanged(index:Int, option:Null<MultiChoiceOption>, previousIndex:Int, previousOption:Null<MultiChoiceOption>):Void {}

    public function onConfirm(index:Int, option:MultiChoiceOption):Void {}

    public function onCancel():Void {}

    public function onPropertyChanged(key:String, value:Dynamic):Void {}

}
