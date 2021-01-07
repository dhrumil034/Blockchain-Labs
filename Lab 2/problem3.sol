pragma solidity ^ 0.5.11;
contract rock_paper_scissors {
    string public player1_choice;
    string public player2_choice;
    address  payable public player1;
    address  payable public player2;
    mapping (string => mapping(string => int)) winner_in_game;
    
    constructor()  public payable{
        winner_in_game["rock"]["rock"] = 0;
        winner_in_game["rock"]["paper"] = 2;
        winner_in_game["rock"]["scissors"] = 1;
        winner_in_game["paper"]["rock"] = 1;
        winner_in_game["paper"]["paper"] = 0;
        winner_in_game["paper"]["scissors"] = 2;
        winner_in_game["scissors"]["rock"] = 2;
        winner_in_game["scissors"]["paper"] = 1;
        winner_in_game["scissors"]["scissors"] = 0;
    }
    
    modifier verify_enough_cash(uint amount){
        if (msg.value<amount)
            revert();
         else 
             _;
    }
    
    modifier not_already_registered() {
        if(player1==msg.sender || player2==msg.sender){
            revert();
        } else {
            _;
        }
    }
    
    function register_player()  public payable verify_enough_cash(5) not_already_registered() {
        if(uint(player1)==0){
            player1 = msg.sender;
        } else if (uint(player2) == 0) {
            player2 = msg.sender;
        }
    }
    
    function play_game(string memory choice) public payable returns (int w) {
        if(msg.sender==player1){
            player1_choice = choice;
        } else if(msg.sender==player2){
            player2_choice = choice;
        }
        
        if(bytes(player1_choice).length!=0 && bytes(player2_choice).length!=0){
            int winner = winner_in_game[player1_choice][player2_choice];
            if(winner==1){
                player1.send(address(this).balance);
            } else if (winner==2){
                player2.send(address(this).balance);
            } else {
                player1.send(address(this).balance/2);
                //since we already send half amount to player1 we will send remaining amount to player2
                player2.send(address(this).balance);
            }
            return winner;
        } else {
            return -1;
        }
    }
    
    function prize_amount() public returns (uint x){
        return address(this).balance;
    }
    
    function get_balance() public returns (uint x){
        return msg.sender.balance;
    }
    
    
}