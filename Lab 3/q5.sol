pragma solidity ^ 0.4.13;

contract SimpleToken {
    
    uint256 totalSupply_;
    
    address owner;
    mapping(address => uint256) balances;
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    
    constructor(uint256 total) public {
        totalSupply_ = total;
        owner = msg.sender;
        balances[msg.sender] = totalSupply_;
    }
    
    function totalSupply() view public returns (uint256){
        return totalSupply_;
    }
    
    function balanceOf(address user) view public returns (uint256){
        return balances[user];
    }
    function transfer(address recipient,uint256 amount) public  payable returns (bool) {
         
        require(amount <= balances[owner]);
         balances[owner]=balances[owner]-amount;
         balances[recipient]=balances[recipient]+amount;
         emit Transfer(owner,recipient,amount);
         return true;
         
     }
    
     function transfer(address from,address recipient,uint256 amount) public  payable returns (bool) {
         
        require(amount <= balances[from]);
         balances[from]=balances[from]-amount;
         balances[recipient]=balances[recipient]+amount;
         emit Transfer(from,recipient,amount);
         return true;
         
     }
    
}

contract Escrow {
    
    enum tx_state { AWAITING_PAYMENT, AWAITING_DELIVERY, AGGREE_SUCCESS,AGREE_FAILURE,DISAGREE,COMPLETE }
    enum party_state {UNDECIDED,TX_SUCCESS,TX_FAIL}

    struct individual_escrow {  
        address buyer;
        address seller;
        address escrow_creator;
        address mediator;
        uint256 amount;
        int timelock;
        party_state  buyer_state;
        party_state  seller_state;
        tx_state contract_state;
    }
    
    SimpleToken token_contract;
    mapping (uint256 => individual_escrow) id_to_escrow_mapping;
    mapping (uint256 => uint256) product_id_to_price;
    
    uint256 current_product_id;
    uint256 current_escrow_id;
    
    modifier onlyBuyer(uint256 escrow_id) {
        require(msg.sender == id_to_escrow_mapping[escrow_id].buyer);
        _;
    }
    
    modifier onlySeller(uint256 escrow_id) {
        require(msg.sender == id_to_escrow_mapping[escrow_id].seller);
        _;
    }
    
    
    modifier verify_contract_state(uint256 escrow_id,tx_state _state) {
        require(id_to_escrow_mapping[escrow_id].contract_state == _state);
        _;
    }
    
    modifier verify_user_state(uint256 escrow_id,address user,party_state _state){
        if(user==id_to_escrow_mapping[escrow_id].buyer){
            require(id_to_escrow_mapping[escrow_id].buyer_state == _state);
        } if(user==id_to_escrow_mapping[escrow_id].seller){
            require(id_to_escrow_mapping[escrow_id].seller_state == _state);
        }
        _;
    }
    
    constructor() public {
        token_contract = new SimpleToken(100000000);
        current_product_id = 0;
    }



    function register_user() {
        token_contract.transfer(msg.sender,100);
    }

    function register_product(uint256 amount) returns (uint256){
        current_product_id = current_product_id+1;
        product_id_to_price[current_product_id] = amount;
        return current_product_id;
    }

    function createEscrow(address buyer,address seller,address third_party,uint256 product_id) public returns (uint256){
        current_escrow_id = current_escrow_id+1;
        individual_escrow memory current_escrow = individual_escrow(buyer,seller,msg.sender,third_party,product_id_to_price[product_id],-1,
                                        party_state.UNDECIDED,party_state.UNDECIDED,tx_state.AWAITING_PAYMENT);
        id_to_escrow_mapping[current_escrow_id] =  current_escrow;                            
        return  current_escrow_id;                          
    }
    
    function MakeDeposit(uint256 escrow_id) onlyBuyer(escrow_id) verify_contract_state(escrow_id,tx_state.AWAITING_PAYMENT) public payable  {
       address current_sender = msg.sender;
       address to_sent = id_to_escrow_mapping[escrow_id].escrow_creator;
       uint256 amount_to_transfer =  getTotalDepositAmount(escrow_id);

        bool success = token_contract.transfer(current_sender,to_sent,amount_to_transfer);
        
        if(success){
            id_to_escrow_mapping[escrow_id].contract_state = tx_state.AWAITING_DELIVERY;
        }
    }
    
    function getTotalDepositAmount(uint256 escrow_id) view public returns (uint256){
        uint256 total_deposit = id_to_escrow_mapping[escrow_id].amount * 101;
        total_deposit = total_deposit / 100;
        return total_deposit;
    }
    
    function ApproveTxSuccess(uint256 escrow_id) verify_user_state(escrow_id,msg.sender,party_state.UNDECIDED) public {
        if(msg.sender==id_to_escrow_mapping[escrow_id].buyer){
            id_to_escrow_mapping[escrow_id].buyer_state = party_state.TX_SUCCESS;
            if(id_to_escrow_mapping[escrow_id].seller_state!=party_state.UNDECIDED){
                        if(id_to_escrow_mapping[escrow_id].seller_state==party_state.TX_SUCCESS){
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.AGGREE_SUCCESS;
                            settle_transcation(escrow_id);
                        } else {
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.DISAGREE;
                            enterTimeLock(escrow_id);
                        }
            }
        } else if(msg.sender==id_to_escrow_mapping[current_escrow_id].seller){
            id_to_escrow_mapping[escrow_id].seller_state = party_state.TX_SUCCESS;
            if(id_to_escrow_mapping[escrow_id].buyer_state!=party_state.UNDECIDED){
                        if(id_to_escrow_mapping[escrow_id].buyer_state==party_state.TX_SUCCESS){
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.AGGREE_SUCCESS;
                            settle_transcation(escrow_id);
                        } else {
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.DISAGREE;
                            enterTimeLock(escrow_id);
                        }
            }
        }
    } 
    
    function ApproveTxFail(uint256 escrow_id) verify_user_state(escrow_id,msg.sender,party_state.UNDECIDED) public{
        if(msg.sender==id_to_escrow_mapping[escrow_id].buyer){
            id_to_escrow_mapping[escrow_id].buyer_state = party_state.TX_FAIL;
            if(id_to_escrow_mapping[escrow_id].seller_state!=party_state.UNDECIDED){
                        if(id_to_escrow_mapping[escrow_id].seller_state==party_state.TX_FAIL){
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.AGREE_FAILURE;
                            settle_transcation(escrow_id);
                        } else {
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.DISAGREE;
                            enterTimeLock(escrow_id);
                        }
            }
        } else if(msg.sender==id_to_escrow_mapping[escrow_id].seller){
            id_to_escrow_mapping[escrow_id].seller_state = party_state.TX_FAIL;
            if(id_to_escrow_mapping[escrow_id].buyer_state!=party_state.UNDECIDED){
                        if(id_to_escrow_mapping[escrow_id].buyer_state==party_state.TX_FAIL){
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.AGREE_FAILURE;
                            settle_transcation(escrow_id);
                        } else {
                            id_to_escrow_mapping[escrow_id].contract_state = tx_state.DISAGREE;
                            enterTimeLock(escrow_id);
                        }
                    
            }
        }
    }
    
    function settle_transcation(uint256 escrow_id) internal{
        if(id_to_escrow_mapping[escrow_id].contract_state==tx_state.AGGREE_SUCCESS){
            token_contract.transfer(id_to_escrow_mapping[escrow_id].escrow_creator,id_to_escrow_mapping[escrow_id].seller,id_to_escrow_mapping[escrow_id].amount);
        } else if(id_to_escrow_mapping[escrow_id].contract_state==tx_state.AGREE_FAILURE){
            token_contract.transfer(id_to_escrow_mapping[escrow_id].escrow_creator,id_to_escrow_mapping[escrow_id].buyer,id_to_escrow_mapping[escrow_id].amount);
        }
        id_to_escrow_mapping[escrow_id].contract_state = tx_state.COMPLETE;
    }
    
    function balanceOf(address user) view public returns (uint256){
        uint256 user_amount= token_contract.balanceOf(user);
        return  user_amount;
    }
    
    function enterTimeLock(uint256 escrow_id) internal {
        uint256 current_block = block.number;
        id_to_escrow_mapping[escrow_id].timelock = int(block.number) + 12;
    }
    
    function Arbitrate(uint256 escrow_id,address winner) verify_contract_state(escrow_id,tx_state.DISAGREE) public returns (bool) {
        if(id_to_escrow_mapping[escrow_id].timelock!=-1  && int(block.number)<= id_to_escrow_mapping[escrow_id].timelock && msg.sender==id_to_escrow_mapping[escrow_id].mediator){
            if(winner==id_to_escrow_mapping[escrow_id].buyer || winner==id_to_escrow_mapping[escrow_id].seller){
                token_contract.transfer(id_to_escrow_mapping[escrow_id].escrow_creator,winner,id_to_escrow_mapping[escrow_id].amount);
                id_to_escrow_mapping[escrow_id].contract_state = tx_state.COMPLETE;
                return true;
            }
        }
        return false;
    }
    
    
    function refund(uint256 escrow_id) onlyBuyer(escrow_id) verify_contract_state(escrow_id,tx_state.DISAGREE) public returns (bool) {
        if(int(block.number) > id_to_escrow_mapping[escrow_id].timelock){
            token_contract.transfer(id_to_escrow_mapping[escrow_id].escrow_creator,id_to_escrow_mapping[escrow_id].buyer,id_to_escrow_mapping[escrow_id].amount);
            id_to_escrow_mapping[escrow_id].contract_state = tx_state.COMPLETE;
            return true;
        }
        return false;
    }
    
    function withdraw(uint256 escrow_id) onlySeller(escrow_id) verify_contract_state(escrow_id,tx_state.DISAGREE) public returns (bool) {
        if(int(block.number) > id_to_escrow_mapping[escrow_id].timelock){
            token_contract.transfer(id_to_escrow_mapping[escrow_id].escrow_creator,id_to_escrow_mapping[escrow_id].buyer,id_to_escrow_mapping[escrow_id].amount);
            id_to_escrow_mapping[escrow_id].contract_state = tx_state.COMPLETE;
            return true;
        }
        return false;
    }
    
    

}