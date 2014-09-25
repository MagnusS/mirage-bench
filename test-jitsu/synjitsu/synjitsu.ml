open V1_LWT
open Printf
open Lwt

module Main (C: CONSOLE) (S: STACKV4) = struct

  module I = Init

  let rec loop c =
    C.log_s c "I'm alive!" >>= fun () ->
    OS.Time.sleep 1. >>= fun () ->
    loop c

  let start c s =
    I.start ();
    Tcpv4.Pcb.set_mode `Fast_start_proxy;

    (* listen on all ports *)
    S.listen_tcpv4 s (-1) (fun _ -> return_unit);

    Lwt.join [
      loop c;
      S.listen s
    ]

end
