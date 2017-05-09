    // a founder offers a 50% share in this account for a price
    // when a partner accepts, their payment is sent to the founder
    // all subsuquent funds removed from the account are split 50/50
    // either the founder or partner may allocate funds for withdrawal
    // each party can then withdraw their pending balance
    // the founder may cancel the offer as long as no one has accepted

pragma solidity 0.4.11;

contract Partnership {
    address public founder;
    address public partner;
    uint askingPrice;
    uint public sharedBalance;
    mapping (address => uint) pendingWithdrawal;
    enum State {Offered, Accepted}
    State public state;

    modifier inState(State s) {if (state != s) throw; _;}
    modifier condition(bool c) {if (!c) throw; _;  }
    modifier onlyFounder() { if (msg.sender != founder) throw; _;}
    modifier onlyOwners() { if (msg.sender != founder && msg.sender != partner) throw; _;}

    event PartnershipOffered(address founder, uint amount);
    event PartnerJoined(address partner);
    event FundsAdded(address sender, uint amount);
    event DistributedFunds(uint share);
    event PaidFunds(address destination, uint amount);
    event OfferCanceled(uint amount);

    function Partnership(address _founder, uint _askingPrice) payable {
        founder = _founder;
        askingPrice = _askingPrice;
        PartnershipOffered(founder, askingPrice);
    }

    function() payable { sharedBalance += msg.value; }

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
        sharedBalance += msg.value;
        FundsAdded(msg.sender, msg.value);
    }

    function distributeFunds(uint _amount)
        onlyOwners
        inState(State.Accepted)
        condition(sharedBalance >= _amount)
        condition(_amount %2 == 0)
    {
        uint share = _amount / 2;
        sharedBalance -= _amount;
        pendingWithdrawal[founder] += share;
        pendingWithdrawal[partner] += share;
        DistributedFunds(share);
    }
 
    function myPendingBalance()
        onlyOwners
        returns (uint)
    {
        return pendingWithdrawal[msg.sender];
    }

    function withdrawFunds(uint _amount)
        onlyOwners
        condition(pendingWithdrawal[msg.sender] >= _amount)
    {
        pendingWithdrawal[msg.sender] -= _amount;
        PaidFunds(msg.sender, _amount);
        if (!msg.sender.send(_amount)) throw;
    }

    function cancelOffer()
        onlyFounder
        inState(State.Offered)
    {
        OfferCanceled(this.balance);
        selfdestruct(founder);
    }
}

contract PartnershipFactory {
    event PartnershipCreated(address newPartnershipAddress);

    function newPartnership(uint _askingPrice)
        public
        payable
        returns (address)
    {
        address _founder = msg.sender;
        address newPartnershipAddress = (new Partnership).value(msg.value)(_founder, _askingPrice);
        PartnershipCreated(newPartnershipAddress);
        return newPartnershipAddress;
    }
}
