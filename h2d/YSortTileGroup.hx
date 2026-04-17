package h2d;

/**
	A TileGroup that splits its content into horizontal strips to allow Y-sorting with other objects.
	
	Items added to this group are distributed into internal TileGroups based on their Y position.
	Use `ysort(layer)` on this object to sort the strips and any other children (like characters) by their Y position.
**/
class YSortTileGroup extends Layers {

	var strips : Map<Int, TileGroup>;
	var curColor : h3d.Vector4;
	
	/**
		The reference tile used as a Texture source to draw.
		Changing this will change the tile for all internal strips.
	**/
	public var tile(default, set) : Tile;

	/**
		The vertical size of the sorting grid.
		Tiles are grouped into strips of this height.
		Objects added to the group will be sorted against these strips.
		Ideally matches your tile height (e.g. 32 or 64).
	**/
	public var gridSize : Int;

	/**
		Create new YSortTileGroup instance.
		@param t The Tile which is used as a source for a Texture to be rendered.
		@param parent An optional parent `h2d.Object` instance.
		@param gridSize The vertical size of the sorting strips (default 32).
	**/
	public function new(?t : Tile, ?parent : h2d.Object, gridSize : Int = 32) {
		super(parent);
		this.tile = t;
		this.gridSize = gridSize;
		strips = new Map();
		curColor = new h3d.Vector4(1, 1, 1, 1);
	}

	function set_tile(t:Tile) {
		this.tile = t;
		for( s in strips )
			s.tile = t;
		return t;
	}

	/**
		Clears all contents and disposes allocated GPU memory.
	**/
	public function clear() {
		for( s in strips ) {
			s.remove();
		}
		strips = new Map();
		// We don't remove other children (like Players) as TileGroup.clear only clears tiles
	}

	/**
		Forces a refresh of the GPU data for all strips.
	**/
	public function invalidate() {
		for( s in strips )
			s.invalidate();
	}

	/**
		Returns the total number of tiles added to the group.
	**/
	public function count() : Int {
		var c = 0;
		for( s in strips )
			c += s.count();
		return c;
	}

	override function onRemove() {
		super.onRemove();
		// Strips are children so they are removed automatically
	}

	/**
		Sets the default tinting color when adding new Tiles.
	**/
	public function setDefaultColor( rgb : Int, alpha = 1.0 ) {
		curColor.x = ((rgb >> 16) & 0xFF) / 255;
		curColor.y = ((rgb >> 8) & 0xFF) / 255;
		curColor.z = (rgb & 0xFF) / 255;
		curColor.w = alpha;
	}

	function getStrip( y : Float ) : TileGroup {
		var index = Math.floor(y / gridSize);
		var s = strips.get(index);
		if( s == null ) {
			s = new TileGroup(tile, this);
			// We set the strip's Y to the BOTTOM of the row.
			// This ensures that objects with Y < bottom_of_row are drawn BEHIND the strip (if ysort called).
			s.y = (index + 1) * gridSize;
			strips.set(index, s);
		}
		return s;
	}

	/**
		Adds a Tile at specified position. Tile is tinted by the current default color.
	**/
	public inline function add(x : Float, y : Float, t : h2d.Tile) {
		var s = getStrip(y);
		s.addColor(x, y - s.y, curColor.x, curColor.y, curColor.z, curColor.w, t);
	}

	/**
		Adds a tinted Tile at specified position.
	**/
	public inline function addColor( x : Float, y : Float, r : Float, g : Float, b : Float, a : Float, t : Tile) {
		var s = getStrip(y);
		s.addColor(x, y - s.y, r, g, b, a, t);
	}

	/**
		Adds a Tile at specified position. Tile is tinted by the current default color RGB value and provided alpha.
	**/
	public inline function addAlpha(x : Float, y : Float, a : Float, t : h2d.Tile) {
		var s = getStrip(y);
		s.addColor(x, y - s.y, curColor.x, curColor.y, curColor.z, a, t);
	}

	/**
		Adds a Tile at specified position with provided transform. Tile is tinted by the current default color.
	**/
	public inline function addTransform(x : Float, y : Float, sx : Float, sy : Float, r : Float, t : Tile) {
		var s = getStrip(y);
		@:privateAccess s.curColor.load(curColor);
		s.addTransform(x, y - s.y, sx, sy, r, t);
	}
	
	/**
		Sorts the content (strips and other children) by Y position.
		Call this in your update loop if objects are moving.
		@param layer The layer index to sort (default 0).
	**/
	public function sort( layer : Int = 0 ) {
		ysort(layer);
	}

}
