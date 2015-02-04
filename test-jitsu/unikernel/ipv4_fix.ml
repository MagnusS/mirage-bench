(* temporary workaround to add to_string/of_string_exn which are needed by fast-start *)
module Make(E:V1_LWT.ETHIF) = struct
        include Ipv4.Make(E)
        let to_string = Ipaddr.V4.to_string
        let of_string_exn = Ipaddr.V4.of_string_exn
end
