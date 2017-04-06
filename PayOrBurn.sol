pragma solidity 0.4.8;
contract payOrBurn {
	address buyer;
	address actor;
	address burnAddress;
	uint value;
	string buyerRequest;
	string actorData;
	enum State {Requested, ActedOn, Paid, Burned}
	State state;
	modifier inState (State s) {if (state != s) throw; _;}
	modifier onlyBuyer() { if (msg.sender != buyer) throw; _;}
	event RequestPosted (string request);
	event ActorReplied (string answer);
	event ActorPaid(uint amount);
	event FundsBurned(uint amount);
	function payOrBurn(string _BuyerRequest) payable {
		buyer = msg.sender;
		value = msg.value;
		burnAddress = 0xdead;
		buyerRequest = _BuyerRequest;
		RequestPosted(_BuyerRequest);
	}
	function actOnRequest(string _ActorData) inState(State.Requested) {
		actor = msg.sender;
		actorData = _ActorData;
		ActorReplied(_ActorData);
		state = State.ActedOn;
	}
	function payActor() onlyBuyer inState(State.ActedOn) {
		if (!actor.send(this.balance)) throw;
		ActorPaid(value);
		state = State.Paid;
	}
	function burnFunds() onlyBuyer inState(State.ActedOn) {
		if (!burnAddress.send(this.balance)) throw;
		FundsBurned(value);
		state = State.Burned;
	}
}