(* some PPX-generated code results in warning 39; turn that off *)
[@@@ocaml.warning "-39"]

module UcharMap : Map.S with type key = Uchar.t

type cross_stitch =
  | Full (* X *) (* full stitch *)
    (* half stitches *)
  | Backslash (* \ *) (* upper left <-> lower right *)
  | Foreslash (* / *) (* lower left <-> upper right *)
    (* quarter stitches *)
  | Backtick (* ` (upper left quadrant) *)
  | Comma (* , (lower left quadrant) *)
  | Reverse_backtick (* mirrored ` (upper right quadrant) *)
  | Reverse_comma (* mirrored , (lower right quadrant) *)
[@@deriving eq, yojson]

type back_stitch =
  | Left | Right | Top | Bottom
[@@deriving eq, yojson]

type stitch = | Cross of cross_stitch
              | Back of back_stitch
[@@deriving eq, yojson]

val pp_stitch : Format.formatter -> stitch -> unit [@@ocaml.toplevel_printer]

type thread = DMC.Thread.t

val pp_thread : Format.formatter -> thread -> unit [@@ocaml.toplevel_printer]

module SymbolMap : Map.S with type key = RGB.t

(* this is rather unimaginative ;) *)
type grid = | Fourteen | Sixteen | Eighteen

val pp_grid : Format.formatter -> grid -> unit [@@ocaml.toplevel_printer]

type substrate =
  { background : RGB.t;
    grid : grid;
    max_x : int; [@generator Crowbar.range 1023](* farthest x coordinate (least is always 0) *)
    max_y : int; [@generator Crowbar.range 1023]
  }

type layer = {
  thread : thread;
  stitch : stitch;
  stitches : (int * int) list;
} [@@deriving yojson]

type pattern = {
  substrate : substrate;
  layers : layer list;
} [@@deriving yojson]

val stitches_at: pattern -> (int * int) -> (stitch * thread) list

val pp_pattern : Format.formatter -> pattern -> unit [@@ocaml.toplevel_printer]

type glyph = {
  stitches : (int * int) list;
  height : int;
  width : int;
} [@@deriving yojson]

type font = glyph UcharMap.t
