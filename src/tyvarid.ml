
type quantifiability = Quantifiable | Unquantifiable
type t = int * kind * quantifiability


let tvidmax : int ref = ref 0

let initialize () = ( tvidmax := 0 )

let fresh kd qtfbl =
  let res = !tvidmax in
  begin
    incr tvidmax ;
    (res, kd, qtfbl)
  end


let same (tvid1 : t) (tvid2 : t) =
  let (tvn1, _) = tvid1 in
  let (tvn2, _) = tvid2 in
    (tvn1 = tvn2)


let show_direct (tvid : t) =
  let (tvn, q) = tvid in
    match !q with
    | Quantifiable   -> string_of_int tvn
    | Unquantifiable -> "_" ^ (string_of_int tvn)


let is_quantifiable (tvid : t) =
  let (_, q) = tvid in
    match !q with
    | Quantifiable   -> true
    | Unquantifiable -> false


let make_unquantifiable_if_needed (tvid1, tvid2) =
  let (_, q1) = tvid1 in
  let (_, q2) = tvid2 in
    match (!q1, !q2) with
    | (Quantifiable, Quantifiable) -> ()
    | _                            -> begin q1 := Unquantifiable ; q2 := Unquantifiable end


let set_quantifiability qtfbl tvid =
  let (tvn, q) = tvid in
    begin
      q := qtfbl ;
      tvid
    end