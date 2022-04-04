// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol";

contract Yoplex is ERC20, ERC20Burnable, Ownable{
    
	address[] private team_wallet;
	uint[] private team_percent;

  struct UserStruct {
        uint id;
        address payable referrerID;
        address[] referral;
        uint investment;
        uint max_investment;
        uint investment_time;
        uint ROI_percent;
        uint ROI_before_investment;
        uint ROI_taken_time;
        uint withdrawal;
        uint withdrawal_time;
        uint[3][3] ROI;
        uint level;
    }

    uint private total_invest = 0;
    uint private withdrawal = 0;
    uint private withdrawal_fee_in_lock = 5;
    uint private withdrawal_fee_after_lock = 1;
    uint private lock_period = 30 days;
    uint private token_price = 1000000;  // 1 USD
    uint private TRX_price = 76000;

    uint[] private min_balance = [50, 5000, 15000];
    uint[] private ROI_percent = [25, 35, 50];
    uint[] private level = [0, 3, 6, 9, 12, 15];

    mapping (address => UserStruct) public users;

    uint private currUserID = 0;

    event regEvent(address indexed _user, address indexed _referrer, uint _time);
    event investEvent(address indexed _user, uint _amount, uint _time);
    event getMoneyEvent(uint indexed _user, uint indexed _referral, uint _amount, uint _level, uint _time);
    event WithdrawalEvent(address indexed _user, uint _amount, uint _time);
    event ROI_WithdrawalEvent(address indexed _user, uint _amount, uint _time);

    constructor(address _account) ERC20("Yoplex", "Yoplex") {

        UserStruct memory userStruct;
        currUserID++;

        userStruct = UserStruct({
            id: currUserID,
            referrerID: payable(address(0)),
            referral: new address[](0),
            investment: 99999999000000,
            max_investment: 99999999000000,
            investment_time: block.timestamp,
            ROI_percent: 2,
            ROI_before_investment: 0,
            ROI_taken_time: block.timestamp,
            withdrawal: 0,
            withdrawal_time: block.timestamp,
            ROI: [[uint(0),uint(0),uint(0)],[uint(0),uint(0),uint(0)],[uint(0),uint(0),uint(0)]],
            level: 0
        });
        users[_account] = userStruct;
    }

	  function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function regUser(address payable _referrerID) public payable {
        require(users[msg.sender].id == 0, "User exist");
        require(msg.value >= min_balance[0], "register with minimum 1 ETH");
        if(_referrerID == address(0)){
            _referrerID = payable(owner());
        }

        total_invest += msg.value;
        currUserID++;

		    UserStruct memory userStruct;
        userStruct = UserStruct({
            id: currUserID,
            referrerID: _referrerID,
            referral: new address[](0),
            investment: TRX_to_USD(msg.value),
            max_investment: TRX_to_USD(msg.value),
            investment_time: block.timestamp,
            ROI_percent: 0,
            ROI_before_investment: 0,
            ROI_taken_time: block.timestamp,
            withdrawal: 0,
            withdrawal_time: block.timestamp,
            ROI: [[TRX_to_USD(msg.value),uint(0),uint(0)],[uint(0),uint(0),uint(0)],[uint(0),uint(0),uint(0)]],
            level: 0
        });
        users[msg.sender] = userStruct;
        users[_referrerID].referral.push(msg.sender);
        for (uint i = 0; i < min_balance.length; i++) {
          if(users[msg.sender].investment >= min_balance[i]){
            users[msg.sender].ROI_percent = i;
          }
        }
        emit regEvent(msg.sender, _referrerID, block.timestamp);
    }

    function invest() public payable {
        require(users[msg.sender].id > 0, "User not exist");
        require(msg.value > 0, "invest with ETH");

        total_invest += msg.value;

        users[msg.sender].ROI_before_investment += viewUserROI(msg.sender);
		    users[msg.sender].ROI_taken_time = block.timestamp;
        users[msg.sender].investment_time = block.timestamp;
        uint before_investment_amt = users[msg.sender].investment;
        uint before_investment_per = users[msg.sender].ROI_percent;
        users[msg.sender].investment += TRX_to_USD(msg.value);
        for (uint i = 0; i < min_balance.length; i++) {
          if(users[msg.sender].investment >= min_balance[i]){
            users[msg.sender].ROI_percent = i;
          }
        }
        uint after_investment_amt = users[msg.sender].investment;
        uint after_investment_per = users[msg.sender].ROI_percent;

        giveROI(msg.sender, after_investment_amt, before_investment_amt, after_investment_per, before_investment_per, 0, 0);

        if(users[msg.sender].investment > users[msg.sender].max_investment){
            users[msg.sender].max_investment = users[msg.sender].investment;
        }

        for (uint i = 0; i < team_wallet.length; i++) {
          payable(team_wallet[i]).transfer(msg.value * team_percent[i] / 100);
        }

        emit investEvent(msg.sender, msg.value, block.timestamp);
    }

    function giveROI(address _user, uint _amountAdd, uint _amountSub, uint _roiAdd, uint _roiSub, uint _gen, uint _dl_amount) internal {
        if(_gen < 21 && _user != address(0)){
            if(_gen < 2){
                users[_user].ROI[_roiAdd][0] += _amountAdd;
                users[_user].ROI[_roiSub][0] -= _amountSub;
            }else if(_gen < 11){
                users[_user].ROI[_roiAdd][1] += _amountAdd;
                users[_user].ROI[_roiSub][1] -= _amountSub;
            }else{
                users[_user].ROI[_roiAdd][2] += _amountAdd;
                users[_user].ROI[_roiSub][2] -= _amountSub;
            }
            if(_gen > 11){
                _dl_amount += users[_user].investment;
            }
            if(users[_user].investment >= 3000 && _dl_amount >= 200000){
                users[_user].level = 1;
                uint count = 0;
                for (uint i = 0; i < users[_user].referral.length; i++) {
                    if(users[users[_user].referral[i]].level == users[_user].level){
                        count ++;
                    }
                }
                if(count > 2){
                    users[_user].level++;
                }
            }
            giveROI(users[_user].referrerID, _amountAdd, _amountSub, _roiAdd, _roiSub, _gen, _dl_amount);
        }
    }

    function viewUserROI(address _user) public view returns(uint) {
        uint ROI = 0;
        for (uint i = 0; i < 3; i++) {
            ROI += users[_user].ROI[i][0] * ROI_percent[i] * ((block.timestamp - users[_user].ROI_taken_time) / 1 days) / 10000;
            if(users[_user].referral.length >= 5){
                ROI += users[_user].ROI[i][1] * ROI_percent[i] * ((block.timestamp - users[_user].ROI_taken_time) / 1 days) / 10000 / 10;
            }
            if(users[_user].level > 0){
                ROI += users[_user].ROI[i][2] * ROI_percent[i] * ((block.timestamp - users[_user].ROI_taken_time) / 1 days) / 10000 * level[users[_user].level] / 100;
            }
        }
        return ROI;
    }

	function USD_to_token(uint _amount) public view returns(uint) {
        return (_amount * 10 ** 6) / token_price;
    }

	function TRX_to_USD(uint _amount) public view returns(uint) {
        return (_amount * TRX_price) / 10 ** 6;
    }

	function USD_to_TRX(uint _amount) public view returns(uint) {
        return (_amount * 10 ** 6) / TRX_price;
    }

    function viewUserReferral(address _user) public view returns(address[] memory) {
        return users[_user].referral;
    }

	function viewUserInvestment_time(address _user) public view returns(uint) {
        return users[_user].investment_time;
    }

	function viewUserInvestment_amount(address _user) public view returns(uint) {
        return users[_user].investment;
    }

	function viewUserWithdrawal_amount(address _user) public view returns(uint) {
        return users[_user].withdrawal;
    }

	function viewUserWithdrawal_time(address _user) public view returns(uint) {
        return users[_user].withdrawal_time;
    }

  function ROI_Withdrawal() public returns (bool) {
		require(users[msg.sender].id > 0, "User not exist");
    uint amount = viewUserROI(msg.sender);
    amount += users[msg.sender].ROI_before_investment;
		users[msg.sender].ROI_taken_time = block.timestamp;
    users[msg.sender].ROI_before_investment = 0;
		payable(msg.sender).transfer(USD_to_TRX(amount));
		emit ROI_WithdrawalEvent(msg.sender, amount, block.timestamp);
    return true;
  }

  function viewUserReleaseAmount(address _user) public view returns (uint) {
      uint amount = 0;
      if(((block.timestamp - users[_user].withdrawal_time) / 30 days) >= 5){
        amount = users[_user].investment;
      }else{
        amount = users[_user].max_investment * (20 * ((block.timestamp - users[_user].withdrawal_time) / 30 days)) / 100;
      }
      if(amount > users[_user].investment){
          amount = users[_user].investment;
      }
      return amount;
  }

	function userWithdrawal() public returns (bool) {
		require(users[msg.sender].id > 0, "User not exist");
		require(users[msg.sender].investment_time + lock_period < block.timestamp, "Token is in lock period");
    uint amount = viewUserReleaseAmount(msg.sender);

    uint before_investment_amt = users[msg.sender].investment;
    uint before_investment_per = users[msg.sender].ROI_percent;
        
		users[msg.sender].investment -= amount;

    for (uint i = 0; i < min_balance.length; i++) {
			if(users[msg.sender].investment >= min_balance[i]){
				users[msg.sender].ROI_percent = i;
			}
		 }
    uint after_investment_amt = users[msg.sender].investment;
    uint after_investment_per = users[msg.sender].ROI_percent;

    giveROI(msg.sender, after_investment_amt, before_investment_amt, after_investment_per, before_investment_per, 0, 0);

    users[msg.sender].withdrawal_time = block.timestamp;
    users[msg.sender].ROI_before_investment += viewUserROI(msg.sender);
    users[msg.sender].ROI_taken_time = block.timestamp;
    users[msg.sender].withdrawal += amount;

		_mint(msg.sender, USD_to_token(amount));
		emit WithdrawalEvent(msg.sender, amount, block.timestamp);
    return true;
  }

	function beneficiaryWithdrawal(address payable _address, uint _amount) public onlyOwner returns (bool) {
        require(_address != address(0), "Enter right adress");
        require(_amount < address(this).balance && _amount > 0, "Enter right amount");
        withdrawal += _amount;
        _address.transfer(_amount);
        return true;
    }

	function update_withdrawal_fee_in_lock(uint _withdrawal_fee_in_lock) onlyOwner public returns (bool) {
        withdrawal_fee_in_lock = _withdrawal_fee_in_lock;
        return true;
    }

	function update_withdrawal_fee_after_lock(uint _withdrawal_fee_after_lock) onlyOwner public returns (bool) {
        withdrawal_fee_after_lock = _withdrawal_fee_after_lock;
        return true;
    }

	function update_lock_period(uint _lock_period) onlyOwner public returns (bool) {
        lock_period = _lock_period;
        return true;
    }

    function update_token_price(uint _price) onlyOwner public returns (bool) {
        TRX_price = _price;
        return true;
    }

    function update_TRX_price(uint _price) onlyOwner public returns (bool) {
        token_price = _price;
        return true;
    }

	function update_min_balance(uint[] memory _min_balance) onlyOwner public returns (bool) {
        min_balance = _min_balance;
        return true;
    }

	function update_ROI_percente(uint[] memory _ROI_percent) onlyOwner public returns (bool) {
        ROI_percent = _ROI_percent;
        return true;
    }

    function update_team(address[] memory _address, uint[] memory _percent) onlyOwner public returns (bool) {
        team_wallet = _address;
        team_percent = _percent;
        return true;
    }

    function teamWallet() public view returns(address[] memory){
        return team_wallet;
    }

    function teamPercent() public view returns(uint[] memory){
        return team_percent;
    }

    function minBalance() public view returns(uint[] memory){
        return min_balance;
    }

    function ROIPercent() public view returns(uint[] memory){
        return ROI_percent;
    }

    function viewLevel() public view returns(uint[] memory){
        return level;
    }

    function updateUserLevel(address _user, uint _level) onlyOwner public returns (bool) {
        users[_user].level = _level;
        return true;
    }

    function totalInvest() public view returns(uint){
        return total_invest;
    }

    function lockPeriod() public view returns(uint){
        return lock_period;
    }

    function tokenPrice() public view returns(uint){
        return token_price;
    }

    function TRXPrice() public view returns(uint){
        return TRX_price;
    }

    function viewWithdrawal() public view returns(uint){
        return withdrawal;
    }

    function withdrawalFeeInLock() public view returns(uint){
        return withdrawal_fee_in_lock;
    }

    function withdrawalFeeAfterLock() public view returns(uint){
        return withdrawal_fee_after_lock;
    } 

    function viewCurrUserID() public view returns(uint){
        return currUserID;
    }   

    function viewUserDetails(address _user) public view returns(UserStruct memory) {
        return users[_user];
    }
}
