open Stitchy
open Types
open Lwt.Infix

module Js = Js_of_ocaml.Js
module CSS = Js_of_ocaml.CSS
module Dom = Js_of_ocaml.Dom

type tool = | Block of thread * stitch
            | Eraser

type editor = {
  tool : tool;
}

let block_size = 20

let default_thread = (List.hd DMC.Thread.basic)

let thread_to_css thread = CSS.Color.hex_of_rgb (DMC.Thread.to_rgb thread)

let init =
  let substrate = {
    background = 255, 255, 255;
    grid = Fourteen;
    max_x = 19;
    max_y = 19;
  }
  and editor = { tool = Block (default_thread, Cross Full) }
  in
  editor, ({ substrate; layers = []; backstitch_layers = [] })

module Html = Js_of_ocaml.Dom_html

let create_canvas size =
  let d = Html.window##.document in
  let c = Html.createCanvas d in
  c##.width := size;
  c##.height := size;
  c

let act_click state editor x y =
  match editor.tool with
  | Block (thread, stitch) ->
    Edit.add_stitch state thread stitch (Canvas.which_block state.substrate x y)
  | Eraser ->
    Edit.remove_stitch state (Canvas.which_block state.substrate x y)

let make_toolbar () =
  let d = Html.window##.document in
  let textbutton s = Html.createButton ~_type:(Js.string "text") ~name:(Js.string s) d in
  let toolbar = Html.getElementById "toolbar"
  and eraser = textbutton "eraser"
  and make_json = textbutton "make_json"
  and upload = textbutton "upload"
  in
  Dom.appendChild eraser (d##createTextNode (Js.string "eraser"));
  Dom.appendChild make_json (d##createTextNode (Js.string "display json"));
  Dom.appendChild upload (d##createTextNode (Js.string "save to server"));

  Dom.appendChild toolbar eraser;
  Dom.appendChild toolbar make_json;
  Dom.appendChild toolbar upload;
  (eraser, make_json, upload)

let make_colorbar editor =
  let d = Html.window##.document in
  let colorbar = Html.getElementById "colorbar" in
  let threads = DMC.Thread.basic in
  (* make some buttons for each one *)
  List.iter (fun thread ->
      (* we happen to know that they're all DMC *)
      let button_color = Html.createButton ~_type:(Js.string "text") d in
      button_color##setAttribute (Js.string "style")
        (Js.string @@ "color:" ^ thread_to_css thread);
      Dom.appendChild button_color (d##createTextNode (Js.string "X"));
      Dom.appendChild colorbar button_color;
      button_color##.onclick := Html.handler (fun _ ->
          editor := { tool = Block (thread, Cross Full) };
          Js._false
        );
    ) threads

let json_display state =
  let d = Html.window##.document in
  let json_element = Html.getElementById "json" in
  let display_id = "json_display" in
  let pre = Html.createPre d in
  pre##.id := Js.string display_id;
  let str = d##createTextNode (Js.string @@ Yojson.Safe.to_string @@ pattern_to_yojson state) in
  Dom.appendChild pre str;
  match Html.getElementById_opt display_id with
  | None ->
    Dom.appendChild json_element pre
  | Some old_json ->
    Dom.replaceChild json_element pre old_json

let load_pattern id =
  Js_of_ocaml_lwt.XmlHttpRequest.get (Format.asprintf "/pattern/%d" id) >>= fun response ->
  match response.Js_of_ocaml_lwt.XmlHttpRequest.code with
  | 200 -> begin
      (* see whether we can translate that json into a pattern *)
      match pattern_of_yojson @@ Yojson.Safe.from_string response.Js_of_ocaml_lwt.XmlHttpRequest.content with
      | Ok state -> Lwt.return @@ Ok state
      | Error s -> Lwt.return @@ Error (Format.asprintf "error getting state from valid json: %s" s)
      | exception (Yojson.Json_error s) ->
        Lwt.return @@ Error (Format.asprintf "error parsing json: %s" s)
    end
  | n ->
    Lwt.return @@ Error (Format.asprintf "failed to get library: code %d, content %s" n
             response.Js_of_ocaml_lwt.XmlHttpRequest.content)

let save_state state =
  (* need to... POST the json to /save, I guess?  :unicode_shrug: *)
  let json = pattern_to_yojson state in
  Js_of_ocaml_lwt.XmlHttpRequest.(perform_raw_url ~content_type:"text/json"
    ~override_method:(`POST)
    ~contents:(`String (Yojson.Safe.to_string json)) "/save")

let start _event =
  (* TODO: figure out a sensible size for the canvas based on window size *)
  (* TODO: also figure out a sensible size for block display *)
  let canvas = create_canvas 300 in
  let editor', state' = init in
  let state, editor = ref state', ref editor' in
  Lwt.ignore_result (
    load_pattern 1 >|= function
    | Error s ->
      let d = Html.window##.document in
      let err = d##createTextNode (Js.string s) in
      let pre = Html.createPre d in
      Dom.appendChild pre err;
      Lwt.return_unit
    | Ok pattern -> state := pattern; Lwt.return_unit
  );
  Canvas.render canvas !state;
  let drawbox = Html.getElementById "drawbox" in
  Dom.appendChild drawbox canvas;
  let (eraser, json, _upload) = make_toolbar () in
  let () = make_colorbar editor in
  drawbox##.onclick := Html.handler (fun event ->
      state := act_click !state !editor event##.clientX event##.clientY;
      Canvas.render canvas !state;
      Js._false
    );
  eraser##.onclick := Html.handler (fun _ ->
      editor := { tool = Eraser } ;
      Js._false
    );
  json##.onclick := Html.handler (fun _ ->
      json_display !state;
      Js._false
    );
  Js._false (* "If the handler returns false, the default action is prevented" *)

let () =
  Html.window##.onload := Html.handler start
