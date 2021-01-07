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
   
    bool deposit_done;
    bool item_received;
    address buyer;
    address seller;
    address escrow_creator;
    address mediator;
    uint256 amount;
    SimpleToken token_contract;
    int timelock;
    
    enum tx_state { AWAITING_PAYMENT, AWAITING_DELIVERY, AGGREE_SUCCESS,AGREE_FAILURE,DISAGREE,COMPLETE }
    enum party_state {UNDECIDED,TX_SUCCESS,TX_FAIL}
    party_state public buyer_state;
    party_state public seller_state;
    tx_state public contract_state;
    
    
    modifier onlyBuyer() {
        require(msg.sender == buyer);
        _;
    }
    
    modifier onlySeller() {
        require(msg.sender == seller);
        _;
    }
    
    
    modifier verify_contract_state(tx_state _state) {
        require(contract_state == _state);
        _;
    }
    
    modifier verify_user_state(address user,party_state _state){
        if(user==buyer){
            require(buyer_state == _state);
        } if(user==seller){
            require(seller_state == _state);
        }
        _;
    }
    
    constructor(address online_buyer,address  online_seller,address third_party,uint256 selling_amount) public {
        buyer = online_buyer;
        seller = online_seller;
        escrow_creator = msg.sender;
        amount = selling_amount;
        mediator = third_party;
        contract_state = tx_state.AWAITING_PAYMENT;
        buyer_state = party_state.UNDECIDED;
        seller_state = party_state.UNDECIDED;
        token_contract = new SimpleToken(selling_amount*2);
        token_contract.transfer(online_buyer,selling_amount*2);
        timelock = -1;
    }
    
    function MakeDeposit() onlyBuyer verify_contract_state(tx_state.AWAITING_PAYMENT) public payable  {
       address current_sender = msg.sender;
       address to_sent = escrow_creator;
       uint256 to_transfer =  getTotalDepositAmount();

        bool success = token_contract.transfer(current_sender,escrow_creator,to_transfer);
        
        if(success){
            contract_state = tx_state.AWAITING_DELIVERY;
        }
    }
    
    function getTotalDepositAmount() view public returns (uint256){
        uint256 total_deposit = amount * 101;
        total_deposit = total_deposit / 100;
        return total_deposit;
    }
    
    function ApproveTxSuccess() verify_user_state(msg.sender,party_state.UNDECIDED) public {
        if(msg.sender==buyer){
            buyer_state = party_state.TX_SUCCESS;
            if(seller_state!=party_state.UNDECIDED){
                        if(seller_state==party_state.TX_SUCCESS){
                            contract_state = tx_state.AGGREE_SUCCESS;
                            settle_transcation();
                        } else {
                            contract_state = tx_state.DISAGREE;
                            enterTimeLock();
                        }
            }
        } else if(msg.sender==seller){
            seller_state = party_state.TX_SUCCESS;
            if(buyer_state!=party_state.UNDECIDED){
                        if(buyer_state==party_state.TX_SUCCESS){
                            contract_state = tx_state.AGGREE_SUCCESS;
                            settle_transcation();
                        } else {
                            contract_state = tx_state.DISAGREE;
                            enterTimeLock();
                        }
            }
        }
    } 
    
    function ApproveTxFail() verify_user_state(msg.sender,party_state.UNDECIDED) public{
        if(msg.sender==buyer){
            buyer_state = party_state.TX_FAIL;
            if(seller_state!=party_state.UNDECIDED){
                        if(seller_state==party_state.TX_FAIL){
                            contract_state = tx_state.AGREE_FAILURE;
                            settle_transcation();
                        } else {
                            contract_state = tx_state.DISAGREE;
                            enterTimeLock();
                        }
            }
        } else if(msg.sender==seller){
            seller_state = party_state.TX_FAIL;
            if(buyer_state!=party_state.UNDECIDED){
                        if(buyer_state==party_state.TX_FAIL){
                            contract_state = tx_state.AGREE_FAILURE;
                            settle_transcation();
                        } else {
                            contract_state = tx_state.DISAGREE;
                            enterTimeLock();
                        }
                    
            }
        }
    }
    
    function settle_transcation() internal{
        if(contract_state==tx_state.AGGREE_SUCCESS){
            token_contract.transfer(escrow_creator,seller,amount);
        } else if(contract_state==tx_state.AGREE_FAILURE){
            token_contract.transfer(escrow_creator,buyer,amount);
        }
        contract_state = tx_state.COMPLETE;
    }
    
    function balanceOf(address user) view public returns (uint256){
        uint256 user_amount= token_contract.balanceOf(user);
        return  user_amount;
    }
    
    function enterTimeLock() internal {
        uint256 current_block = block.number;
        timelock = int(block.number) + 12;
    }
    
    function Arbitrate(address winner) verify_contract_state(tx_state.DISAGREE) public returns (bool) {
        if(timelock!=-1  && int(block.number)<= timelock && msg.sender==mediator){
            if(winner==buyer || winner==seller){
                token_contract.transfer(escrow_creator,winner,amount);
                contract_state = tx_state.COMPLETE;
                return true;
            }
        }
        return false;
    }
    
    
    function refund() onlyBuyer verify_contract_state(tx_state.DISAGREE) public returns (bool) {
        if(int(block.number) > timelock){
            token_contract.transfer(escrow_creator,buyer,amount);
            contract_state = tx_state.COMPLETE;
            return true;
        }
        return false;
    }
    
    function withdraw() onlySeller verify_contract_state(tx_state.DISAGREE) public returns (bool) {
        if(int(block.number) > timelock){
            token_contract.transfer(escrow_creator,buyer,amount);
            contract_state = tx_state.COMPLETE;
            return true;
        }
        return false;
    }
    
}