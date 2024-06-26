open Syntax
open Syntax.Lambda
open Syntax.Combinator
open Numbers

let generic_ski ~(conv_com_str : Combinators.com_str -> 'a)
    ~(pp_result : Format.formatter -> 'a -> unit)
    (m : Combinators.com_str lambda) : 'a combinator =
  let rec lambda_to_comb : Combinators.com_str lambda -> 'a combinator =
    function
    | Var v -> CVar (conv_com_str v)
    | Abs _ -> assert false
    | App (m, n) -> CApp (lambda_to_comb m, lambda_to_comb n)
  in
  let com s = Var (`Com s) in
  let pp = Lambda.pp Combinators.pp_com_str in
  let rec aux m =
    (* Format.eprintf "Converting: %a\n"
       (pp_lambda (fun fmt v ->
            let s =
              match v with `Com s -> combinators_to_str s | `Str s -> s
            in
            Format.fprintf fmt "%s" s))
       m; *)
    match m with
    | Var (`Str s) when String.get s 0 = '$' -> (
        let s = String.sub s 1 (String.length s - 1) in
        try aux @@ List.assoc s !Library.library
        with Not_found -> failwith ("Undefined variable $" ^ s))
    | Var (`Str s) when String.get s 0 = '*' ->
        let n = int_of_string @@ String.sub s 1 (String.length s - 1) in
        let res = aux @@ n2charchnum n ~add_bcom:true in
        Logs.info (fun a -> a "Numconv: %d => %a" n pp res);
        res
    | Var (`Str s) when String.get s 0 = '#' ->
        let n = int_of_string @@ String.sub s 1 (String.length s - 1) in
        let res = aux @@ n2charchnum n ~add_bcom:false in
        Logs.info (fun a -> a "Numconv: %d => %a" n pp res);
        res
    | Var _ -> m
    | Abs (v, m) when Lambda.is_free m v -> App (com `K, aux m)
    | Abs (v, (Abs _ as m)) -> aux (Abs (v, aux m))
    | Abs (v, App (m, n)) ->
        let tm = aux (Abs (v, m)) in
        let tn = aux (Abs (v, n)) in
        App (App (com `S, tm), tn)
    | Abs (v, Var w) when v = w -> com `I
    | Abs (_, (Var _ as m)) -> App (com `K, m)
    | App (m, n) -> App (aux m, aux n)
  in
  let m = aux m in
  Logs.info (fun a -> a "Converting: %a" pp m);
  let res = lambda_to_comb m in
  Logs.info (fun a -> a "Converted in comb: %a" (Combinator.pp pp_result) res);
  res

let ski =
  generic_ski
    ~conv_com_str:(function
      | `Com c -> c | `Str s -> failwith @@ "Not-converted free variable " ^ s)
    ~pp_result:Combinators.pp

let ski_allow_str =
  generic_ski ~conv_com_str:(fun x -> x) ~pp_result:Combinators.pp_com_str
