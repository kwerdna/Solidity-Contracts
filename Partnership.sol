pragma solidity 0.4.8;
contract Partnership {
    address founder = msg.sender;
    address partner;
    uint askingPrice;
    //uint public creationTime = now;
    enum State {Offered, Accepted}
    State state;

    modifier inState(State s) {if (state != s) throw; _;}
    modifier condition(bool c) {if (!c) throw; _;  }
    modifier onlyFounder() { if (msg.sender != founder) throw; _;}
    modifier onlyOwners() { if (msg.sender != founder && msg.sender != partner) throw; _;}

    event PartnershipOffered(address founder, uint _amount);
    event PartnerJoined(address partner);
    event FundsAdded(address sender, uint amount);
    event PaidFunds(address destination, uint amount);
    event OfferCanceled(uint amount);

    function Partnership(uint _askingPrice) {
        askingPrice = _askingPrice;
        PartnershipOffered(founder, askingPrice);
    }

    function purchasePartnership()
        payable
        inState(State.Offered)
        condition(msg.value == askingPrice)
    {
        partner = msg.sender;
        PartnerJoined(partner);
        if (!founder.send(askingPrice)) throw;
        PaidFunds(founder, askingPrice);
        state = State.Accepted;
    }

    function addPayment() payable {
        FundsAdded(msg.sender, msg.value);
    }

    function distributeFunds(uint _amount)
        onlyOwners
        inState(State.Accepted)
        condition(_amount <= this.balance)
        condition(_amount %2 == 0)
    {
        if (!partner.send(_amount / 2)) throw;
        PaidFunds(partner, _amount / 2);
        if (!founder.send(_amount / 2)) throw;
        PaidFunds(founder, _amount / 2);
    }
    function cancelOffer()
        onlyFounder
        inState(State.Offered)
    {
        OfferCanceled(this.balance);
        selfdestruct(founder);
    }
}