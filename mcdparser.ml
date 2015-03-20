
exception StackUnderflow

exception LineUnderflow

module Stack : sig

	type 'a t

	val empty : 'a t
	val pop : ('a t ref) -> 'a
	val push : ('a t ref) -> 'a -> unit
	val to_list : ('a t) -> ('a list)

end = struct

  type 'a t = 'a list

  let empty = []

  (* 'a t ref -> 'a *)
  let pop stk =
    match !stk with
      [] -> raise StackUnderflow
    | head :: tail -> (stk := tail ; head)

  (* 'a t ref -> 'a -> unit *)
  let push stk cnt =
    stk := cnt :: !stk

  (* 'a t -> 'a t -> 'a t *)
  let rec concat lsta lstb =
    match lsta with
      [] -> lstb
    | head :: tail -> head :: (concat tail lstb)

  (* 'a t -> 'a list *)
  let rec to_list lst =
    match lst with
      [] -> []
    | head :: tail -> concat (to_list tail) [head]

end

(*
module McdParser : sig

  type nonterminal = Total | Sentence | Block | Group | Args | Params
  type tree = Empty | Terminal of token | NonTerminal of nonterminal * (tree list)
  type state = (unit -> unit)
  type tree_and_state = tree * state

  val mcdparser : (token list) -> (tree list)

end = struct
*)
  type nonterminal = Total | Sentence | Block | Group | Args | Params
  type tree = Terminal of token | NonTerminal of nonterminal * (tree list)

  type state = (unit -> unit)
  type tree_and_state = tree * state

  let input_line : tree list ref = ref []
  let output_stack : tree_and_state Stack.t ref = ref Stack.empty

  (* string -> unit *)
  let report_error errmsg =
    print_string ("[Error in mcdparser] " ^ errmsg ^ ":") ; print_newline ()

  (* unit -> tree *)
  let pop_from_line () =
    match !input_line with
      [] -> raise LineUnderflow (*error*)
    | head :: tail -> (input_line := tail ; head)

  (* unit -> tree *)
  let top_of_line () =
    match !input_line with
      [] -> raise LineUnderflow (*error*)
    | head :: tail -> head

  (* token list -> tree list *)
  let rec convert_token_list_into_tree_list toklst =
    match toklst with
      [] -> []
    | head :: tail -> (Terminal(head)) :: (convert_token_list_into_tree_list tail)

  (* 'a list -> 'a list -> 'a list *)
  let rec concat_lists lsta lstb =
    match lsta with
      [] -> lstb
    | head :: tail -> head :: (concat_lists tail lstb)

  (* token list -> unit *)
  let make_line input =
    input_line := convert_token_list_into_tree_list input

  let rec eliminate_state lst =
    match lst with
      [] -> []
    | (tr, st) :: tail -> tr :: (eliminate_state tail)


  let rec mcdparser (input: token list) =
    make_line input ;
    output_stack := Stack.empty ;

    q_first () ;
    eliminate_state (Stack.to_list !output_stack)

  (* tree -> state -> unit *)
  and shift content q =
    Stack.push output_stack (content, q) ; q ()

  (* nonterminal * int -> unit *)
  and reduce nontm num =
    print_string "reduce" ; print_newline () ;
    reduce_sub [] nontm num q_dummy

  (* tree list -> nonterminal -> int -> unit *)
  (* surely contains bug *)
  and reduce_sub trlst nontm num q =
    if num == 0 then (
      Stack.push output_stack (NonTerminal(nontm, trlst), q) ; q ()
    ) else
      let trandst = Stack.pop output_stack in
        match trandst with
          (tr, st) -> reduce_sub (concat_lists trlst [tr]) nontm (num - 1) st

  and reduce_empty nontm q =
    print_string "reduce_empty" ; print_newline () ;
    shift (NonTerminal(nontm, [])) q

  and q_dummy () =
    print_string "q_dummy" ; print_newline () ;
    ()

  and q_first () =
    print_string "q_first" ; print_newline () ;
  (*
    T -> .B [$]
    B -> .S B
    B -> .              (reduce [$])
    S -> .[var] [end]
    S -> .[char]
    S -> .[pop] [var] [var] G
    S -> .[macro] [ctrlseq] A G
    S -> .[macrowid] [ctrlseq] A G G
    S -> .[ctrlseq] [end]
    S -> .[ctrlseq] [id] [end]
    S -> .[ctrlseq] G P
    S -> .[ctrlseq] [id] G P
  *)
    match top_of_line () with
      Terminal(END_OF_INPUT) -> reduce_empty Block q_first
    | _ -> (
    	let popped = pop_from_line () in
        match popped with
          NonTerminal(Block, lst) -> shift popped q_end
        | NonTerminal(Sentence, lst) -> shift popped q_after_sentence
        | Terminal(VAR(c)) -> q_var1 ()
        | Terminal(CHAR(c)) -> q_char ()
        | Terminal(POP) -> q_pop1 ()
        | Terminal(MACRO) -> q_macro1 ()
(*        | Terminal(MACROWID) -> q_macrowid1 () *)
        | Terminal(CTRLSEQ(c)) -> q_after_ctrlseq ()
        | _ -> report_error "illegal first token"
    )

  and q_after_sentence () =
    print_string "q_after_sentence" ; print_newline () ;
  (*
    B -> S.B
    B -> .S B
    B -> .             (reduce [$], [}])
    S -> .[var] [end]
    S -> .[char]
    S -> .[pop] [var] [var] G
    S -> .[macro] [ctrlseq] A G
    S -> .[macrowid] [ctrlseq] A G G
    S -> .[ctrlseq] [end]
    S -> .[ctrlseq] [id] [end]
    S -> .[ctrlseq] G P
    S -> .[ctrlseq] [id] G P
  *)
    match top_of_line () with
      Terminal(EGRP) -> reduce_empty Block q_after_sentence
    | Terminal(END_OF_INPUT) -> reduce_empty Block q_after_sentence
    | _ -> (
      let popped = pop_from_line () in
        match popped with
          NonTerminal(Block, lst) -> shift popped q_after_block
        | NonTerminal(Sentence, lst) -> shift popped q_after_sentence
        | Terminal(VAR(c)) -> shift popped q_var1
        | Terminal(CHAR(c)) -> shift popped q_char
        | Terminal(POP) -> shift popped q_pop1
        | Terminal(MACRO) -> shift popped q_macro1
(*        | Terminal(MACROWID) -> shift popped q_macrowid1 *)
        | Terminal(CTRLSEQ(c)) -> shift popped q_after_ctrlseq
        | _ -> report_error "inappropriate token after sentence"
    )

  and q_inner_of_group () =
    print_string "q_inner_of_group" ; print_newline () ;
  (*
    B -> [{].B [}]
    B -> .S B
    B -> .             (reduce [$], [}])
    S -> .[var] [end]
    S -> .[char]
    S -> .[pop] [var] [var] G
    S -> .[macro] [ctrlseq] A G
    S -> .[macrowid] [ctrlseq] A G G
    S -> .[ctrlseq] [end]
    S -> .[ctrlseq] [id] [end]
    S -> .[ctrlseq] G P
    S -> .[ctrlseq] [id] G P
  *)
    match top_of_line () with
      Terminal(EGRP) -> reduce_empty Block q_inner_of_group
    | Terminal(END_OF_INPUT) -> reduce_empty Block q_inner_of_group
    | _ -> (
      let popped = pop_from_line () in
        match popped with
          NonTerminal(Block, lst) -> shift popped q_after_block
        | NonTerminal(Sentence, lst) -> shift popped q_after_sentence
        | Terminal(VAR(c)) -> shift popped q_var1
        | Terminal(CHAR(c)) -> shift popped q_char
        | Terminal(POP) -> shift popped q_pop1
        | Terminal(MACRO) -> shift popped q_macro1
(*        | Terminal(MACROWID) -> shift popped q_macrowid1 *)
        | Terminal(CTRLSEQ(c)) -> shift popped q_after_ctrlseq
        | _ -> report_error "inappropriate token after sentence"
    )

  and q_var1 () =
    print_string "q_var1" ; print_newline () ;
  (*
    S -> [var].[end]
  *)
    let popped = pop_from_line () in
      match popped with
        Terminal(END) -> shift popped q_var2
      | _ -> report_error "missing semicolon after variable"

  and q_var2 () =
    print_string "q_var2" ; print_newline () ;
  (*
    S -> [var] [end].
  *)
    reduce Sentence 2

  and q_char () =
    print_string "q_char" ; print_newline () ;
  (*
    S -> [char].
  *)
    reduce Sentence 1

  and q_pop1 () =
    print_string "q_pop1" ; print_newline () ;
  (*
    S -> [pop].[var] [var] G
  *)
    let popped = pop_from_line () in
      match popped with
        Terminal(VAR(c)) -> shift popped q_pop2
      | _ -> report_error "missing first variable after \\pop"

  and q_pop2 () =
    print_string "q_pop2" ; print_newline () ;
  (*
    S -> [pop] [var].[var] G
  *)
    let popped = pop_from_line () in
      match popped with
        Terminal(VAR(c)) -> shift popped q_pop3
      | _ -> report_error "missing second variable after \\pop"

  and q_pop3 () =
    print_string "q_pop3" ; print_newline () ;
  (*
    S -> [pop] [var] [var].G
    G -> .[{] B [}]
  *)
    let popped = pop_from_line () in
      match popped with
        Terminal(BGRP) -> shift popped q_inner_of_group
      | _ -> report_error "missing { after \\pop"

  and q_macro1 () =
    print_string "q_macro1" ; print_newline () ;
  (*
    S -> [macro].[ctrlseq] A G
  *)
    let popped = pop_from_line () in
      match popped with
        Terminal(CTRLSEQ(c)) -> shift popped q_macro2
      | _ -> report_error "missing control sequence after \\macro"

  and q_macro2 () =
    print_string "q_macro2" ; print_newline () ;
  (*
    S -> [macro] [ctrlseq].A G
    A -> .[var] A
    A -> .
  *)
    match top_of_line () with
      Terminal(BGRP) -> reduce_empty Args q_macro2 (*?*)
    | Terminal(EGRP) -> reduce_empty Args q_macro2
    | Terminal(END_OF_INPUT) -> reduce_empty Args q_macro2
    | _ -> (
      let popped = pop_from_line () in
        match popped with
          NonTerminal(Args, lst) -> shift popped q_macro3
        | Terminal(VAR(c)) -> shift popped q_args
        | _ -> report_error "inappropriate argument in \\macro declaration"
    )

  and q_macro3 () =
    print_string "q_macro3" ; print_newline () ;
  (*
    S -> [macro] [ctrlseq] A.G
    G -> .[{] B [}]
  *)
    let popped = pop_from_line () in
      match popped with
        NonTerminal(Group, lst) -> shift popped q_macro4
      | Terminal(BGRP) -> shift popped q_inner_of_group
      | _ -> report_error "missing group in \\macro declaration"

  and q_macro4 () =
    print_string "q_macro4" ; print_newline () ;
  (*
    S -> [macro] [ctrlseq] A G.
  *)
    reduce Sentence 4

  and q_args () =
    print_string "q_args" ; print_newline () ;
  (*
  	A -> [var].A
  	A -> .[var] A
  	A -> .
  *)
    match top_of_line () with
      Terminal(BGRP) -> reduce_empty Args q_args (*?*)
    | Terminal(EGRP) -> reduce_empty Args q_args
    | Terminal(END_OF_INPUT) -> reduce_empty Args q_args
    | _ -> (
      let popped = pop_from_line () in
        match popped with
          NonTerminal(Args, lst) -> shift popped q_macro3
        | Terminal(VAR(c)) -> shift popped q_args
        | _ -> report_error "inappropriate argument in \\macro declaration"
    )

  and q_after_ctrlseq () =
    print_string "q_after_ctrlseq" ; print_newline () ;
  (*
    S -> [ctrlseq].[end]
    S -> [ctrlseq].[id] [end]
    S -> [ctrlseq].G P
    S -> [ctrlseq].[id] G P
    G -> .[{] B [}]
  *)
    let popped = pop_from_line () in
      match popped with
        NonTerminal(Group, lst) -> shift popped q_after_first_group
      | Terminal(END) -> shift popped q_ctrlseq_A
      | Terminal(ID(c)) -> shift popped q_after_id
      | Terminal(BGRP) -> shift popped q_inner_of_group
      | _ -> report_error "illegal token after control sequence"

  and q_after_first_group () =
    print_string "q_after_first_group" ; print_newline () ;
  (*
    S -> [ctrlseq] G.P
    P -> .G P
    P -> .
    G -> .[{] B [}]
  *)
    match top_of_line () with
      Terminal(EGRP) -> reduce_empty Params q_after_first_group
    | Terminal(END_OF_INPUT) -> reduce_empty Params q_after_first_group
    | _ -> (
      let popped = pop_from_line () in
        match popped with
          NonTerminal(Params, lst) -> shift popped q_ctrlseq_C
        | NonTerminal(Group, lst) -> shift popped q_params
        | Terminal(BGRP) -> shift popped q_inner_of_group
        | _ -> report_error "inappropriate token after group"
    )

  and q_after_id () =
    print_string "q_after_id" ; print_newline () ;
  (*
    S -> [ctrlseq] [id].[end]
    S -> [ctrlseq] [id].G P
    G -> .[{] B [}]
  *)
    let popped = pop_from_line() in
      match popped with
        NonTerminal(Group, lst) -> shift popped q_after_id_and_first_group
      | Terminal(END) -> shift popped q_ctrlseq_C
      | Terminal(BGRP) -> shift popped q_inner_of_group
      | _ -> report_error "inappropriate token after ID"

  and q_after_id_and_first_group () =
    print_string "q_after_id_and_first_group" ; print_newline () ;
  (*
    S -> [ctrlseq] [id] G.P
    P -> .G P
    P -> .
    G -> .[{] B [}]
  *)
    match top_of_line () with
      Terminal(EGRP) -> reduce_empty Params q_after_id_and_first_group
    | Terminal(END_OF_INPUT) -> reduce_empty Params q_after_id_and_first_group
    | _ -> (
      let popped = pop_from_line () in
        match popped with
          NonTerminal(Params, lst) -> shift popped q_ctrlseq_D
        | NonTerminal(Group, lst) -> shift popped q_params
        | Terminal(BGRP) -> shift popped q_inner_of_group
        | _ -> report_error "inappropriate token after id and first group"
    )

  and q_params () =
    print_string "q_params" ; print_newline () ;
  (*
  	P -> G.P
  	P -> .G P
  	P -> .
  	G -> .[{] B [}]
  *)
    match top_of_line () with
      Terminal(EGRP) -> reduce_empty Params q_params
    | Terminal(END_OF_INPUT) -> reduce_empty Params q_params
    | _ -> (
    	let popped = pop_from_line () in
    	  match popped with
    	    NonTerminal(Params, lst) -> shift popped q_params_end
    	  | NonTerminal(Group, lst) -> shift popped q_params
    	  | Terminal(BGRP) -> shift popped q_inner_of_group
    	  | _ -> report_error "inappropriate parameter"
    )

  and q_params_end () =
    print_string "q_params_end" ; print_newline () ;
  (*
  	  P -> G P.
  *)
    reduce Params 2

  and q_ctrlseq_A () =
    print_string "q_ctrlseq_A" ; print_newline () ;
  (*
    S -> [ctrlseq] [end].
  *)
    reduce Sentence 2

  and q_ctrlseq_B () =
    print_string "q_ctrlseq_B" ; print_newline () ;
  (*
    S -> [ctrlseq] [id] [end].
  *)
    reduce Sentence 3

  and q_ctrlseq_C () =
    print_string "q_ctrlseq_C" ; print_newline () ;
  (*
    S -> [ctrlseq] G P.
  *)
    reduce Sentence 3

  and q_ctrlseq_D () =
    print_string "q_ctrlseq_D" ; print_newline () ;
  (*
    S -> [ctrlseq] [id] G P.
  *)
    reduce Sentence 4

  and q_after_block () =
    print_string "q_after_block" ; print_newline () ;
  (*
    B -> S B.
  *)
    reduce Block 2

  and q_end () =
    print_string "q_end" ; print_newline () ;
  (*
    T -> B.[$]
  *)
    let popped = pop_from_line () in
      match popped with
        Terminal(END_OF_INPUT) -> shift popped q_end_of_end (*end of parsing*)
      | _ -> report_error "illegal end"

  and q_end_of_end () =
    print_string "q_end_of_end" ; print_newline () ;
  (*
  	T -> B [$].
  *)
    reduce Total 2
(*
end
*)