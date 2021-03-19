(* This file is part of Dream, released under the MIT license. See
   LICENSE.md for details, or visit https://github.com/aantron/dream.

   Copyright 2021 Anton Bachin *)



(* http://www.lastbarrier.com/public-claims-and-how-to-validate-a-jwt/ *)
(* https://jwt.io/ *)

module Dream = Dream__pure.Inmost

(* module Log = (val Fw.Logger.create_log "mw.csrf" : Fw.Logger.LOG) *)

(* TODO LATER The crypto situation in OCaml seems a bit sad; it seems necessary
   to depend on gmp etc. Is this in any way avoidable? *)
(* TODO LATER Perhaps jose + mirage-crypto can solve this. Looks like it needs
   an opam release. *)

(* let log =
  Dream.Log.sub_log "dream.csrf" *)

(* TODO Generate/use real secrets. *)
(* let secret = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" *)

(* The current version of the Dream CSRF token puts a hash of the session ID
   into the plaintext portion of a signed JWT, and compares session hashes. The
   hash function must therefore be (relatively?) secure against collision
   attacks.

   A future implementation is likely to encrypt the token, including the
   session ID, instead, in which case it may e possible to avoid hashing it. *)
(* TODO Generalize the session accessor so that this CSRF token generator can
   work with community session managers. *)
let hash_session request =
  request
  |> Session.Exported_defaults.session_key
  |> Digestif.SHA256.digest_string
  |> Digestif.SHA256.to_raw_string
  |> Dream__pure.Formats.to_base64url

  (* Dream.base64url
    (Digest.string (Dream.Session.key (Dream.Session.get request))) *)

(* TODO Use a stronger hash of the session ID. *)
(* TODO Encrypt tokens for some security by obscurity? *)
(* TODO Consider scoping to form. That would allow e.g. using a long-lived token
   for a logout POST form, while shorter-lived tokens are used for other
   interactions. *)

(* TODO Restore logging with ids of some kind. *)

(* let identify_hash hash =
  String.sub hash 0 3 *)

(* TODO Make the expiration configurable. In particular, AJAX CSRF tokens
   may need longer expirations... OTOH maybe not, as they can be refreshed. *)

let valid_for =
  Int64.of_int (60 * 60)

let token request =
  let secret = Dream.secret (Dream.app request) in
  let session_hash = hash_session request in
  let now = Unix.gettimeofday () |> Int64.of_float in
  (* let tag = Dream.base64url (Dream.random 6) in *)

  let payload = [
    "session", session_hash;
    "time", Int64.to_string (Int64.add now valid_for);
  ] in

  (* log.debug (fun m ->
    m ~request "Session %s (hash prefix %s): new CSRF token %s"
      (Session.identify request) (identify_hash hash) tag)
  |> ignore; *)

  Jwto.encode Jwto.HS256 secret payload |> Result.get_ok
  (* TODO Can this fail? *)

let field_name = "dream.csrf"

(* TODO Check expiration. *)
(* TODO More graceful handling of bad CSRF, like re-sending the form with
   non-sensitive fields filled in as before. *)
(* TODO Rename m to log in logging. *)

(* TODO Be more verbose... *)
let verify token request =
  let secret = Dream.secret (Dream.app request) in

  match Jwto.decode_and_verify secret token with
  | Error _ -> false
  | Ok decoded_token ->

    match Jwto.get_payload decoded_token with
    | ["session", token_session_hash; "time", expires_at] ->

      let now = Unix.gettimeofday () |> Int64.of_float in
      begin match Int64.of_string_opt expires_at with
      | Some expires_at when expires_at > now ->

        let real_session_hash = hash_session request in
        token_session_hash = real_session_hash

      | _ -> false
      end

    | _ -> false



(* let verify handler request =
  (* let csrf, req = Form.consume field req in *)
  let csrf, request = [[""]], request in
  let valid =
    match csrf with
    | [[token]] ->
      begin match Jwto.decode_and_verify secret token with
      | Ok value ->
        begin match Jwto.get_payload value with
        | ["id", hash; "tag", tag; "time", _] ->
          hash = hash_session request || begin
            log.debug (fun m -> m ~request
              "Session %s (hash prefix %s): got CSRF token %s for %s"
              (Session.identify request) (hash_session request) tag hash);
            log.warning (fun m -> m ~request "CSRF token mismatch");
            false
          end
        | _ ->
          log.warning (fun m -> m ~request "CSRF token: bad payload");
          false
        end
      | _ ->
        log.warning (fun m -> m ~request "CSRF token: invalid");
        false
      end
    | _ ->
      log.warning (fun m ->
        m ~request "CSRF token: missing or multiple values");
      false
  in
  if valid then
    handler request
  else
    Dream.respond ~status:`Bad_Request "" *)