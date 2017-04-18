pragma solidity 0.4.8;
contract payOrBurn {
    address buyer;
    address actor;
    address constant burnAddress = 0xdead;
    string buyerRequest;
    uint deposit;
    string actorData;
    enum State {Requested, Committed}
    State state;

    modifier inState (State s) {if (state != s) throw; _;}
    modifier condition(bool c) {if (!c) throw; _;  }
    modifier onlyBuyer() { if (msg.sender != buyer) throw; _;}
    modifier onlyActor() { if (msg.sender != actor) throw; _;}

    event RequestPosted (address requestedBy, string request, uint value, uint deposit);
    event RequestUpdated (string request);
    event ActorCommitted (address _actor, string answer, uint _depositAmount);
    event ActorDataUpdated (string answer);
    event ActorPaid(uint amount);
    event FundsBurned(uint amount);
    event RequestCanceled(uint amount);

    function () payable {}

    function payOrBurn(string _BuyerRequest, uint _depositInWei) payable {
        buyer = msg.sender;
        deposit = _depositInWei;
        buyerRequest = _BuyerRequest;
        RequestPosted(buyer, buyerRequest, msg.value, deposit);
    }

    function updateBuyerRequest(string _BuyerRequest)
        onlyBuyer
        condition(this.balance > 0)
    {
        buyerRequest = _BuyerRequest;
        RequestUpdated(buyerRequest);
    }

    function cancelRequest()
        onlyBuyer
        inState(State.Requested)
    {
        RequestCanceled(this.balance);
        selfdestruct(buyer);
    }

    function commitToFulfillRequest(string _ActorData)
        payable
        inState(State.Requested)
        condition(msg.value == deposit)
    {
        actor = msg.sender;
        actorData = _ActorData;
        ActorCommitted(actor, actorData, msg.value);   
        state = State.Committed;
    }

    function updateActorData( string _ActorData)
        inState(State.Committed)
        onlyActor
        condition(this.balance > 0)
    {
        actorData = _ActorData;
        ActorDataUpdated(actorData);
    }

    function payActor(uint _amount)
        onlyBuyer
        inState(State.Committed)
        condition(_amount <= this.balance)
    {
        if (!actor.send(_amount)) throw;
        ActorPaid(_amount);
    }

    function burnFunds(uint _amount)
        onlyBuyer
        inState(State.Committed)
        condition(_amount <= this.balance)
    {
        if (!burnAddress.send(_amount)) throw;
        FundsBurned(_amount);
    }
}