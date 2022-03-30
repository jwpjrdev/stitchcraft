open Stitchy
open Types
open Lwt.Infix

module Js = Js_of_ocaml.Js
module CSS = Js_of_ocaml.CSS
module Dom = Js_of_ocaml.Dom

let thread_to_css thread = CSS.Color.hex_of_rgb (DMC.Thread.to_rgb thread)

module Html = Js_of_ocaml.Dom_html

let create_canvas pattern ~max_width ~max_height =
  let d = Html.window##.document in
  let c = Html.createCanvas d in
  let w = max_width
  and h = max_height
  in
  let canvas_smallest = max 1 (min w h) in
  let pattern_largest = (max pattern.substrate.max_x pattern.substrate.max_y) + 1 in
  let block_size = canvas_smallest / pattern_largest in
  c##.width := block_size * (pattern.substrate.max_x + 1);
  c##.height := block_size * (pattern.substrate.max_y + 1);
  {Canvas.canvas = c; block_size}

let load_pattern tag =
  let d = Html.window##.document in
  let json =
    match Js.Opt.to_option @@ d##getElementById (Js.string tag) with
    | None -> "{}"
    | Some e -> match Js.Opt.to_option e##.textContent with
      | None -> "{}"
      | Some e -> Js.to_string e
  in
  match Yojson.Safe.from_string json with
  | exception Stack_overflow -> Lwt.return @@ Error "this string is too big to parse as json"
  | s ->
  match pattern_of_yojson s with
  | Ok state -> Lwt.return @@ Ok state
  | Error s -> Lwt.return @@ Error (Format.asprintf "error getting state from valid json: %s" s)
  | exception (Yojson.Json_error s) ->
    Lwt.return @@ Error (Format.asprintf "error parsing json: %s" s)
  | exception Stack_overflow ->
    Lwt.return @@ Error "this JSON is too big to parse as a pattern"

let ul_of_threads (threads : Estimator.thread_info list) =
  let li_of_thread thread =
    let li = Html.createLi Html.window##.document in
    li##.textContent := Js.Opt.return (Js.string @@ Format.asprintf "%a" Estimator.pp_thread_info thread);
    li
  in
  let alphabetize = List.sort (fun (a : Estimator.thread_info) b -> Stitchy.DMC.Thread.compare a.thread b.thread) in
  let ul = Html.createUl Html.window##.document in
  let lis = List.map li_of_thread (alphabetize threads) in
  List.iter (Dom.appendChild ul) lis;
  ul

let start _event =
  Lwt.ignore_result (
    let d = Html.window##.document in
    load_pattern "json" >|= function
    | Error s ->
      let error_element = Html.getElementById "error" in
      let err = d##createTextNode (Js.string s) in
      Dom.appendChild error_element err;
      Lwt.return_unit
    | Ok pattern ->
      let grid = Html.getElementById "grid"
      and materials = Html.getElementById "materials_list"
      in
      let max_width = Html.window##.innerWidth
      and max_height = Html.window##.innerHeight
      in
      let canvas = create_canvas ~max_width ~max_height pattern in
      Canvas.render canvas pattern;
      Dom.appendChild grid Canvas.(canvas.canvas);
      let bill_of_materials = Estimator.materials ~margin_inches:1. pattern in
      let ul = ul_of_threads bill_of_materials.threads in
      Dom.appendChild materials ul;
      Lwt.return_unit
  );
  Js._false (* "If the handler returns false, the default action is prevented" *)

let () =
  Html.window##.onload := Html.handler start
