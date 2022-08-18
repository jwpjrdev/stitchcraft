open Stitchy.Types
open Patbrowser_canvas

let dir =
  let doc = "directory from which to read." in
  Cmdliner.Arg.(value & pos 0 dir "." & info [] ~doc)

type traverse = {
  n : int;
  contents : Fpath.t list;
}

let start_view = { Patbrowser_canvas__Controls.x_off = 0; y_off = 0; zoom = 1; block_display = `Symbol }

let rec ingest dir traverse =
  match List.nth_opt traverse.contents traverse.n with
  | None -> Error "off end of list"
  | Some filename ->
    match Bos.OS.File.read filename with
    | Error _ ->
      (* are there additional files to try? *)
      ingest dir {traverse with n = traverse.n + 1}
    | Ok contents ->
      (try
         Ok (Yojson.Safe.from_string contents)
       with _ -> Error "not json")
      |> function
      | Ok j -> Stitchy.Types.pattern_of_yojson j
      | Error _ as e -> e

(* we don't assume the patterns will update.
 * we're dealing with static, predetermined stuff *)
let disp dir =
  let open Lwt.Infix in
  let rec aux dir traverse : unit Lwt.t =
    let term = Notty_lwt.Term.create () in
    let user_input_stream = Notty_lwt.Term.events term in
    match ingest dir traverse with
    | Error _ -> Notty_lwt.Term.image term (Notty.I.string Notty.A.empty "nope")
    | Ok pattern ->
      Notty_lwt.Term.image term @@ main_view pattern start_view (Notty_lwt.Term.size term) >>= fun () ->
      let rec loop (pattern : pattern) (view : Patbrowser_canvas__Controls.view) =
        (Lwt_stream.last_new user_input_stream) >>= fun event ->
          let size = Notty_lwt.Term.size term in
          match step pattern view size event with
          | `Quit, _ -> Notty_lwt.Term.release term
          | `None, view ->
            Notty_lwt.Term.image term (main_view pattern view size) >>= fun () ->
            loop pattern view
          | `Next, _view -> aux dir {traverse with n = traverse.n + 1}
          | `Prev, _view -> aux dir {traverse with n = max 0 @@ traverse.n - 1}
      in
      loop pattern start_view
  in
  (
    let open Rresult.R in
    Fpath.of_string dir >>= fun dir ->
    Bos.OS.Dir.contents dir >>= function
    | [] -> Error (`Msg "no patterns")
    | contents ->
      let traverse = {
        n = 0;
        contents;
      } in
      Lwt_main.run @@ aux dir traverse; Ok ()
  ) |> function
  | Ok () -> Ok ()
  | Error (`Msg s) -> Format.eprintf "%s\n%!" s; Error s

let info =
  let doc = "slice, dice, and tag patterns" in
  Cmdliner.Cmd.info "patbrowser" ~doc

let disp_t = Cmdliner.Term.(const disp $ dir)

let () =
  exit @@ Cmdliner.Cmd.eval_result @@ Cmdliner.Cmd.v info disp_t
