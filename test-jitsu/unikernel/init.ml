open Lwt
open Printf
open V1_LWT

(* From synjitsu/fast-start/init.ml *)

let mutate_string f s =
  String.iteri (fun i c ->
      let x = f c in
      if x = c then ()
      else s.[i] <- x
    ) s;
  s

let xs_key = function
  | "" -> "/ip"
  | k  ->
    let k = "/ip/" ^ k in
    mutate_string (function '.' -> '-' | x   -> x) k

let safe_read h k =
  Lwt.catch
    (fun () -> OS.Xs.read h k >>= fun v -> return (Some v))
    (function Xs_protocol.Enoent _ -> return_none | e -> fail e)

let read xs k =
  let k = xs_key k in
  printf "read %s\n" k;
  OS.Xs.(immediate xs (fun h -> safe_read h k))

let remove xs k =
  let k = xs_key k in
  printf "remove %s\n" k;
  OS.Xs.(immediate xs (fun h -> rm h k))

let write xs kvs =
  let kvs = List.map (fun (k, v) -> xs_key k, v) kvs in
  let str =
    String.concat " " (List.map (fun (k, v) -> sprintf "%s:%s" k v) kvs)
  in
  printf "write %s\n" str;
  OS.Xs.(transaction xs (fun h ->
      Lwt_list.iter_p (fun (k, v) -> write h k v) kvs
    ))

let watch xs k =
  let k = xs_key k in
  printf "watch %s\n" k;
  OS.Xs.(wait xs (fun h ->
      safe_read h k >>= function
      | None   -> fail Xs_protocol.Eagain
      | Some _ -> return_unit
    ))

let directory xs k =
  let k = xs_key k in
  printf "directory %s\n" k;
  OS.Xs.(immediate xs (fun h -> directory h k)) >>= fun dirs ->
  List.map (fun dir ->
      mutate_string (function '-' -> '.' | c -> c) dir
    ) dirs
  |> return

let start () =
  let module KV: Tcpv4.Pcb.KV.S = struct
    let mk fn x =
      OS.Xs.make () >>= fun xs ->
      fn xs x
    let read x = mk read x
    let write x = mk write x
    let remove x = mk remove x
    let watch x = mk watch x
    let directory x = mk directory x
  end in
  Tcpv4.Pcb.KV.set (module KV)
