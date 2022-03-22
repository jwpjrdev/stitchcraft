open Stitchy
open Types

type t = {
  block_size : int;
  canvas : Js_of_ocaml.Dom_html.canvasElement Js_of_ocaml.Js.t;
}

let thread_to_css thread = Js_of_ocaml.CSS.Color.hex_of_rgb (DMC.Thread.to_rgb thread)

let render_stitch {canvas; block_size} _stitch thread (x, y) =
  let context = canvas##getContext (Js_of_ocaml.Dom_html._2d_) in
  context##.fillStyle := Js_of_ocaml.Js.string @@ thread_to_css thread;
  context##fillRect
    (* x offset *) (float_of_int (x * block_size))
    (* y offset *) (float_of_int (y * block_size))
    (* width *) (float_of_int block_size)
    (* length *) (float_of_int block_size)

let render_grid ?(minor_index= 5) ?(major_index = 20) {canvas; block_size} piece =
  let linewidth index = match index mod minor_index with
    | 0 -> if index mod major_index = 0 then 3. else 2.
    | _ -> 1.
  in
  let context = canvas##getContext (Js_of_ocaml.Dom_html._2d_) in
  let draw_col_line index =
    context##beginPath;
    context##.lineWidth := linewidth index;
    let x = float_of_int @@ index * block_size in
    context##moveTo x 0.;
    context##lineTo x
      (float_of_int @@ (piece.max_y + 1) * block_size);
    context##stroke
  in
  let draw_row_line index =
    context##beginPath;
    context##.lineWidth := linewidth index;
    let y = float_of_int @@ index * block_size in
    context##moveTo 0. y;
    context##lineTo (float_of_int @@ (piece.max_x + 1) * block_size)
      y;
    context##stroke
  in
  let rec aux f = function
    | k when k < 0 -> ()
    | n -> (f n; aux f (n-1))
  in
  aux draw_col_line (piece.max_x + 1);
  aux draw_row_line (piece.max_y + 1)

let render_layer canvas layer =
  CoordinateSet.iter (render_stitch canvas layer.stitch layer.thread) layer.stitches

let render_background {canvas; block_size} substrate =
  (* draw a big ol' rectangle of the background color *)
  let far_x = (substrate.max_x + 1) * block_size
  and far_y = (substrate.max_y + 1) * block_size
  in 
  let context = canvas##getContext (Js_of_ocaml.Dom_html._2d_) in
  context##.fillStyle := Js_of_ocaml.(Js.string @@ CSS.Color.hex_of_rgb substrate.background);
  context##fillRect
    (* x offset *) 0.
    (* y offset *) 0.
    (* width *) (float_of_int far_x)
    (* length *) (float_of_int far_y)

let render canvas state =
  render_background canvas state.substrate;
  render_grid canvas state.substrate;
  List.iter (render_layer canvas) state.layers