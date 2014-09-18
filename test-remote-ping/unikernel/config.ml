open Mirage

let fs = crunch "./htdocs"

let ipv4_config = 
      let address = Ipaddr.V4.of_string_exn "192.168.2.10" in
      let netmask = Ipaddr.V4.of_string_exn "255.255.255.0" in
      let gateways = [Ipaddr.V4.of_string_exn "192.168.2.1"] in
      { address; netmask; gateways }

let stack console = direct_stackv4_with_static_ipv4 console tap0 ipv4_config

let server =
  http_server 80 (stack default_console)

let main =
  foreign "Dispatch.Main" (console @-> kv_ro @-> http @-> job)

let () =
  add_to_ocamlfind_libraries ["re.str"];
  add_to_opam_packages ["re"];

  register "www" [
    main $ default_console $ fs $ server
  ]
