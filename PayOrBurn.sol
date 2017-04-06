pragma solidity 0.4.8;
contract payOrBurn {
	address buyer;
	address actor;
	uint value;
	string buyerRequest;
	string actorData;
	enum State {Requested, ActedOn}
	State state;
	modifier inState (State s) {if (state != s) throw; _;}
	modifier condition(bool c) {if (!c) throw; _;  }
	modifier onlyBuyer() { if (msg.sender != buyer) throw; _;}
	event RequestPosted (string request);
	event ActorReplied (string answer);
	event ActorPaid(uint amount);
	event FundsBurned(uint amount);
	function payOrBurn(string _BuyerRequest) payable {
		buyer = msg.sender;
		value = msg.value;
		buyerRequest = _BuyerRequest;
		RequestPosted(_BuyerRequest);
	}
	function actOnRequest(string _ActorData) inState(State.Requested) {
		actor = msg.sender;
		actorData = _ActorData;
		ActorReplied(_ActorData);
		state = State.ActedOn;
	}
	function payActor(uint _amount)
		onlyBuyer
		inState(State.ActedOn)
		condition(_amount <= this.balance)
	{
		if (!actor.send(_amount)) throw;
		ActorPaid(_amount);
	}
	function burnFunds(uint _amount)
		onlyBuyer
		inState(State.ActedOn)
		condition(_amount <= this.balance)
	{
		if (!burnAddress().send(_amount)) throw;
		FundsBurned(_amount);
	}
	function burnAddress() constant returns(address) {
    	return 0xdead;   
	} 
}