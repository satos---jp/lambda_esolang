open Syntax
open Syntax.Lambda
open Syntax.Combinators
open Syntax.Combinator

let s2comb s =
  let rec aux = function
    | Var v -> CVar v
    | Abs _ -> assert false
    | App (m, n) -> CApp (aux m, aux n)
  in
  aux @@ Library.s2lam s

let com_to_lambda : 'a combinator -> 'a lambda =
  let rec aux = function
    | CVar v -> Var v
    | CApp (m, n) -> App (aux m, aux n)
  in
  aux

exception StepLimit

let jot2comb n =
  let v = n2bin n in
  List.fold_left
    (fun acc x ->
      if x = 0 then CApp (CApp (acc, CVar (`Com `S)), CVar (`Com `K))
      else CApp (CVar (`Com `S), CApp (CVar (`Com `K), acc)))
    (CVar (`Com `I))
    v

let reduce_comb_one_step =
  let rec aux m =
    match m with
    | CApp (CVar (`Com `I), m) -> m
    | CApp (CApp (CVar (`Com `K), m), _) -> m
    | CApp (CApp (CApp (CVar (`Com `S), m), n), o) ->
        aux (CApp (CApp (m, o), CApp (n, o)))
    | CVar (`Com (`Jot x)) -> jot2comb x
    | CVar _ as m -> m
    | CApp (m, n) -> CApp (aux m, aux n)
  in
  aux

let reduce_comb m =
  let base_size = Combinator.size m in
  let step = ref 0 in

  let _pp = Combinator.pp ComStrFv.pp in
  let rec loop m =
    if Combinator.size m > base_size * 100 then raise StepLimit;
    if !step > 10000 then raise StepLimit;
    step := !step + 1;
    let tm = reduce_comb_one_step m in
    (* Format.eprintf "Reduction: %a -> %a\n" _pp m _pp tm; *)
    if tm = m then m else loop tm
  in
  try
    let tm = loop m in
    (* Format.eprintf "Reduction: %a => %a\n" pp m pp tm ; *)
    Some tm
  with StepLimit -> (* Format.eprintf "Reduction Timeout: %a\n" pp m; *)
                    None

let rec size = function
  | Var _ -> 1
  | Abs (_, m) -> size m + 1
  | App (m, n) -> size m + size n + 1
