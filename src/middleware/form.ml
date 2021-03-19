(* This file is part of Dream, released under the MIT license. See
   LICENSE.md for details, or visit https://github.com/aantron/dream.

   Copyright 2021 Anton Bachin *)



module Dream = Dream__pure.Inmost



(* TODO Restore logging. *)
(* let log =
  Dream.Log.sub_log "dream.form" *)

let sort form =
  List.stable_sort (fun (key, _) (key', _) -> String.compare key key') form

(* TODO Debug metadata. *)
(* let key =
  Dream.new_local () *)

(* TODO Custom CSRF checker or session implementation. *)

let form request =
  let open Lwt.Infix in

  match Dream.header "Content-Type" request with
  | Some "application/x-www-form-urlencoded" ->

    Dream.body request
    >>= fun body ->

    let form = Dream__pure.Formats.from_form_urlencoded body in
    let csrf_token, form =
      List.partition (fun (name, _) -> name = Csrf.field_name) form in

    begin match csrf_token with
    | [_, value] ->
      if not (Csrf.verify value request) then
        Lwt.return (Error `CSRF_token_invalid)
      else
        Lwt.return (Ok (sort form))

    | _ -> Lwt.return (Error `CSRF_token_invalid)
    end

  | _ -> Lwt.return (Error `Not_form_urlencoded)

(* TODO Add built-in Content-Type thing. *)
(* TODO Provide well-known Content-Types as predefined strings. *)
(* let urlencoded handler request =
  let open Lwt.Infix in

  match Dream.header "Content-Type" request with
  | Some "application/x-www-form-urlencoded" ->
    Dream.body request >>= fun body ->
    let form = sort (Dream.from_form_urlencoded body) in
    Dream.with_local key form request
    |> handler
  | content_type ->
    log.warning (fun m -> m ~request
      "Bad Content-Type '%s'" (Option.value content_type ~default:""));
    (* TODO Need a convenience function for generating a bad request. *)
    Dream.respond ~status:`Bad_Request ""

(* TODO Use the optional. *)
let get request =
  Dream.local key request |> Option.get
  (* try
    Opium.Context.find_exn key req.env
  with exn ->
    Middleware.missing req name;
    raise exn *)

let consume field request =
  let form = get request in
  let matching, rest =
    List.partition (fun (field', _) -> field' = field) form in
  let matching = List.map snd matching in
  matching, Dream.with_local key rest request *)