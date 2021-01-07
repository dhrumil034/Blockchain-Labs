var Web3 = require('web3');
var web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

var events = require('events');
var em = new events.EventEmitter();

var concatenated_log = '';

em.on('logData',function(data){
  append_log(data);
});

/* web3.eth.getBlockNumber(function(error, result){ if(!error) console.log(result) }) */
var defaultAcc = ""; 

setDefaultAccount();

function server() {
  var user = {
    'userA':'pwd123',
    'userB':'pwd456',
  };
  var fileX = "This is the file from server";
  var filePermissionBit = {
    'userA':0,
    'userB':0
  };
  var loginStatus = {
    'userA':0,
    'userB':0
  };

  this.user_Login = function(userId,pwd) {
    if(user[userId] == pwd)
    {
      loginStatus[userId] = 1;
      em.emit('logData','user with id '+userId+' successfully logged in');
    }
  }
  
  this.user_Logout = function(userId) {
    loginStatus[userId] = 0;
    em.emit('logData','user with id '+userId+' successfully logged in');
  }
  
  this.file_permission_set = function(user) {
    filePermissionBit[user] = 1;
    em.emit('logData','user with id '+user+' got the permission to read the file');
  }
  
  this.file_delegate = function( delegator,  delegatee) {
    if(filePermissionBit[delegator] == 1)
    {
      console.log(delegator +" giving file-read permission to "+delegatee);
      filePermissionBit[delegatee] = 1;
    }
  }
  
  this.file_Access = function(user) {
    if(loginStatus[user] == 1 && filePermissionBit[user] == 1)
    {
      em.emit('logData','user with id '+user+' accessed the file');
      return fileX;
    }
    em.emit('logData','user with id '+user+' failed to access file');
    return "You are not authorized to read this file.";
  }
}

function client(){
  server1=new server();
  this.execute = function() {
    server1.user_Login("userA","pwd123");
    server1.user_Login("userB","pwd456");
    
    server1.file_permission_set("userA");
    var response = server1.file_Access("userA");
    console.log("Response after userA reading file:"+response);
    response=server1.file_Access("userB");
    console.log("Response after userB reading file:"+response);
    
    server1.file_delegate("userA","userB");
    response = server1.file_Access("userB");
    console.log("Response after userB reading file :"+response);

    server1.user_Logout("userA");
    server1.user_Logout("userB");
    bkc_logging(); 
  }  
}

/*Function to generate hex encoded value for input string & sending transaction to blockchain for logging puropse*/
function bkc_logging(){ 
  let str_hex = web3.utils.toHex(concatenated_log);  
  web3.eth.sendTransaction({from:defaultAcc,data:str_hex,to:defaultAcc},function(err,success) {
    if (err)
      console.log("Failed to Send Transcation");
    else {
      console.log("sucsess");
      var receipt = web3.eth.getTransactionReceipt(success,function(err, transaction) {
        console.info(transaction);    
      });
    }
  });
}

function append_log(str){
  concatenated_log = concatenated_log.concat(str);
}

/*Function to get a account from local blockchain*/
function setDefaultAccount(){
  web3.eth.getAccounts(function(error, result){
    if(!error){
      defaultAcc  = result[0];
      var client1 = new client();
      client1.execute();
    }}
  );
}
