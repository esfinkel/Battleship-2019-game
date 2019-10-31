let clear_screen () =
  ANSITerminal.(erase Screen)


(** [print_grid grid] prints the string representation of grid
    (string list list) [grid]. *)
let print_grid grid =
  let print_cell c = ANSITerminal.( match c with
      | "w" -> print_string [cyan] "w "
      | "x" -> print_string [white; on_black] "x "
      | "?" -> print_string [white; on_black] "? "
      | "O" -> print_string [white; on_black] "O "
      | "X" -> print_string [red] "X "
      | "#" -> print_string [red] "# "
      | _ -> ()
    )
  in
  let print_row i row =
    Char.chr (i+65) |> print_char;
    print_string " ";
    List.iter print_cell row;
    print_newline ()
  in
  let rec print_nums s e =
    if s <= e then (print_string " "; print_int s; print_nums (s+1) e) else ()
  in
  print_newline ();
  print_string " ";
  print_nums 1 (List.length (List.nth grid 0));
  print_newline ();
  List.iteri print_row grid

(** [print_self_board b] prints the colorful string representation of
    board [b], as seen by the board's player. *)
let print_self_board b =
  b |> Board.string_self |> print_grid

(** [print_other_board b] prints the colorful string representation of
    board [b], as seen by other playesr. *)
let print_other_board b =
  b |> Board.string_other |> print_grid



(** [print_help] prints the list of valid commands. *)
let print_help unit : unit = 
  ANSITerminal.(
    print_string [cyan] 
      (String.concat "\n" 
         [ "\n\nGame set-up commands:";
           "Use 'place' <ship name> 'on' <coordinate 1> <coordinate 2>"
           ^ " to place a ship on the board.";
           "Use 'ready' when your board is set up and ready to play.";
           "\n Gameplay commands:";
           "Use 'shoot' and a coordinate to shoot that spot";
           "Use 'status' to see what ships you still have.";
           "Use 'quit' to quit the game."
         ])); ()

let read_command unit : string =
  print_string "\n> ";
  match read_line () with
  | exception End_of_file -> "End of file exception thrown."
  | new_command -> new_command

let display_board board =
  print_other_board board;
  print_self_board board

let try_placing (ship_phrase: string list) board =
  match ship_phrase with
  | name::l1::l2::[] -> (
      match Board.place name l1 l2 board with
      | exception Board.OffBoard -> 
        ANSITerminal.
          (print_string [red] (
              "\n\nYou cannot place the ship"
              ^ "there.\nPlease enter coordinates that are on" 
              ^ " the board.")
          );
      | exception Board.Misaligned -> 
        ANSITerminal.
          (print_string [red]
             ("\n\nYou cannot place the ship with those "
              ^ "coordinates. Coordinates must be in the "
              ^ "same row or column."));
      | exception Board.WrongLength -> 
        ANSITerminal.
          (print_string [red]
             ("\n\nYou cannot place this ship with "
              ^ "those coordinates. The ship must have" 
              ^ " the right length"));
      | exception Board.InvalidShipName ->
        ANSITerminal.(print_string [red] 
                        ("\n\nYou cannot place that ship."
                         ^ " Please enter a valid ship name."));
      | exception Board.OverlappingShips ->
        ANSITerminal.(print_string [red] 
                        ("\n\nYou cannot place that ship there."
                         ^ " There is already a ship on those coordinates."
                         ^ " Try placing the ship on a different location."));
      | () -> print_self_board board;
        print_endline ("\n\nYou placed the "  ^  name);
        Board.setup_status board |> print_endline
    )
  | _ -> print_endline "\n parsing error"


let rec continue_setup board  = 
  match Command.parse (read_command ()) with
  | Place ship_phrase -> try_placing ship_phrase board; 
    (* display_board board; *)
    if Board.complete board then
      print_endline "All ships placed.\nType 'ready' to continue." else ();
    continue_setup board 
  | Help -> print_help (); 
    continue_setup board 
  | Quit -> exit 0;
  | Ready -> if Board.complete board then () else
      (ANSITerminal.(print_string [red] "No you're not! Make sure all your ships are placed.");
       continue_setup board)
  | Status -> ANSITerminal.(
      print_string [red]
        "\n\nYou cannot check your game status until you begin playing."
    );
    continue_setup board
  | Shoot _ -> ANSITerminal.(
      print_string [red]
        "\n\nYou cannot shoot until you begin playing."
    );
    continue_setup board
  | exception Command.Malformed -> ANSITerminal.(
      print_string [red] "Please input a valid command."
    );
    continue_setup board 
  | exception Command.Empty -> ANSITerminal.(
      print_string [red] "Please input a valid command."
    );
    continue_setup board 

(** [setup board] starts the process of setting up [board].*)
let setup board  =
  print_self_board board;  Board.setup_status board |> print_endline;
  ANSITerminal.(
    print_string [cyan]
      ("\n\n"^(Board.player_name board)^": please set up your board." 
       ^ "\nUse 'place' <ship name> 'on' <coordinate 1> <coordinate 2>"
       ^ "\nUse 'ready' when all your ships are placed to continue.")
  );
  continue_setup board

let try_shooting shoot_phrase board =
  match shoot_phrase with 
  | loc::[] -> begin 
      match Board.shoot loc board with 
      | exception Board.DuplicateShot -> ANSITerminal.(
          print_string [red] "You've already shot there! Try shooting somewhere else!"
        );
      | exception Board.InvalidLoc -> ANSITerminal.(
          print_string [red] "You can't shoot there! Try shooting somewhere else!"
        );
      | _ -> display_board board; 
        print_endline ("You shot: " ^ loc); end
  | _ -> print_endline "\n parsing error"


let rec continue_game board = 
  match Command.parse (read_command ()) with
  | Place _ -> 
    print_endline "You can't move your ships during the game!"; 
    continue_game board 
  | Help -> print_help (); 
    continue_game board 
  | Quit -> exit 0;
  | Ready -> (* Need a way to check if the opponent has shot yet. 
                Maybe a mutable field similar to ship._onboard. *) 
    continue_game board;
  | Status -> ANSITerminal.(
      print_string [cyan] (Board.status board)
    );
    continue_setup board
  | Shoot shoot_phrase -> try_shooting shoot_phrase board;
    (* Need a way to check if the opponent has shot yet. 
       Maybe a mutable field similar to ship._onboard. *) 
    continue_game board
  | exception Command.Malformed -> ANSITerminal.(
      print_string [red] "Please input a valid command."
    );
    continue_game board 
  | exception Command.Empty -> ANSITerminal.(
      print_string [red] "Please input a valid command."
    );
    continue_game board 

let setup_game board = 
  display_board board; 
  ANSITerminal.(
    print_string [cyan]
      ("\n\n"^(Board.player_name board)^": please make your move." 
       ^ "\nUse 'shoot' <coordinate 1> to shoot that location"
       ^ "\nUse 'status' to check your status"));
  continue_game board

(** [check_p2_name p1_name] checks the name each player inputs is not empty 
    and is different than [p1_name]. *)
let rec check_p2_name p1_name =
  let x = read_command () in 
  if (x = p1_name) || (
      x 
      |> String.split_on_char ' ' 
      |> List.filter (fun x -> x <> "") = []
    )  
  then (print_endline "Please enter a valid name."; 
        check_p2_name p1_name) else x

let get_names () =  print_endline "Player 1 name?";
  let p1_name = check_p2_name "" in
  print_endline "Player 2 name?";
  let p2_name = check_p2_name p1_name in 
  (p1_name, p2_name)

(** [multiplayer ()] prompts for the game to play, then starts it. *)
let multiplayer () = 
  ANSITerminal.(print_string [cyan]
                  "\n\nWelcome to Battleship!\n");
  let p1, p2 = get_names () in
  let p1_board = Board.init_board p1 in
  let p2_board = Board.init_board p2 in
  clear_screen ();
  setup p1_board; clear_screen ();
  setup p2_board; clear_screen ();
  setup_game p1_board;
  print_endline "this is where gameplay would be."


(** [main ()] prompts for the game to play, then starts it. *)
let main () = multiplayer ()


(* Execute the game engine. *)
let () = main () 