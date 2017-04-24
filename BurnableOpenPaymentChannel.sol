// first whack at a payment channel
// with an open burnable twist.
//
// a seller constructs the contract by sending ether and includes
// data/message/payload and the amount of the 1st payment requested.
// in this example byte8 is used as the payload, but it could be another type.
// the sellers balance is credited w/ the amount of eth sent.
// the seller can cancel the channel if nobody has activated it yet.
//
// a buyer activates the chanel by sending at least as much eth as the seller sent.
// the buyer's balance is credited with the amount of ether sent.
// the amount of the first payment is deducted from the buyer's balance
// and credited to the seller's balance.
//
// the seller sends a payment request including a new data/payload and amount.
//
// if the buyer approves a payment request they have the option of continuing
// the payment channel or closing it.
// if the buyer declines a payment request the amount of the request is
// deducted from the balance of BOTH parties and burned. the channel is then closed.
//
// the seller can cancel a pending payment request.
//
// the buyer can add funds to their balance while the channel is still active.
//
// the seller can close the channel at any time.
// the buyer can close the channel when there is no payment request pending.
//  
// after the channel has closed, both parites can collect their share of ether in the account.
//
pragma solidity 0.4.8;
contract paymentChannel {
    address seller = msg.sender;
    address buyer;
    address burnAddress = 0xdead;
    // keep track of amounts
    uint public sellerBalance;
    uint public buyerBalance;
    uint public nextPayment;
 
    // states to keep track of   
    enum WaitingFor {Buyer, Seller}
    WaitingFor wait;
    enum State {Open, Active, Closed}
    State state;

    modifier inState(State s) {if (state != s) throw; _;}
    modifier condition(bool c) {if (!c) throw; _;  }
    modifier onlySeller {if (msg.sender != seller) throw; _;}
    modifier onlyBuyer {if (msg.sender != buyer) throw; _;}
    modifier eitherParty {if (msg.sender != buyer && msg.sender != seller) throw; _;}
    modifier NoPaymentDue {if (msg.sender == buyer && nextPayment > 0) throw; _;}

    // cheap storage
    event ChannelOpened(uint AmountDeposited);
    event ChannelCanceled(uint AmountRefunded);
    event ChannelActivated(uint AmountDeposited);
    event PaymentRequested(bytes8 Data);
    event PaymentRequestCanceled();
    event PaymentApproved(uint PaymentAmount);
    event PaymentDeclined();
    event ChannelClosed();
    event BuyerShareCollected(uint AmountWithdrawn);
    event SellerShareCollected(uint AmountWithdrawn);
    event FundsAdded(uint AmountAdded);

    function paymentChannel(bytes8 _data, uint _firstPayment)
        payable
    {
        sellerBalance = msg.value;
        wait = WaitingFor.Buyer;
        nextPayment = _firstPayment;
        ChannelOpened(msg.value);
        PaymentRequested(_data);
    }

    function cancelChannel()
        inState(State.Open)
    {
        ChannelCanceled(this.balance);
        selfdestruct(seller);
    }

    function activateChannel()
        payable
        inState(State.Open)
        condition(msg.sender != seller)
        condition(msg.value >= sellerBalance)
    {
        buyer = msg.sender;
        buyerBalance = msg.value;
        state = State.Active;
        ChannelActivated(buyerBalance);
        approvePayment(false);
    }

   function requestPayment(uint _amount, bytes8 _data)
        onlySeller
        inState(State.Active)
        condition(wait == WaitingFor.Seller)
        condition(_amount <= buyerBalance)
        condition(_amount <= sellerBalance)
    {
        nextPayment = _amount;
        wait = WaitingFor.Buyer;
        PaymentRequested(_data);
    }

   function approvePayment(bool _closeChannel)
        onlyBuyer
        inState(State.Active)
        condition(nextPayment <= buyerBalance)
        condition(wait == WaitingFor.Buyer)
    {
        uint amountPaid = nextPayment;
        nextPayment = 0;
        buyerBalance -= amountPaid;
        sellerBalance += amountPaid;
        wait = WaitingFor.Seller;
        PaymentApproved(amountPaid);
        if (_closeChannel == true) {
            closeChannel();
        }
    }

    function cancelPaymentRequest()
        onlySeller
        inState(State.Active)
        condition(wait == WaitingFor.Buyer)
        condition (nextPayment > 0)
    {
        nextPayment = 0;
        wait = WaitingFor.Seller;
        PaymentRequestCanceled();
    }

    function declinePayment()
        onlyBuyer
        inState(State.Active)
        condition(wait == WaitingFor.Buyer)
    {
        // tmp var in memory
        uint _amount = nextPayment;
        buyerBalance -= _amount;
        sellerBalance -= _amount;
        nextPayment = 0;
        PaymentDeclined();
        closeChannel();
        if (!burnAddress.send(_amount * 2)) throw;
    }

   function addFunds()
        payable
        onlyBuyer
        inState(State.Active)
    {
        buyerBalance += msg.value;
        FundsAdded(msg.value);
    }

    function closeChannel()
        eitherParty
        inState(State.Active)
        NoPaymentDue
    {
        state = State.Closed;
        ChannelClosed();
    }

    function collectShare()
        eitherParty
        inState(State.Closed)
    {
        uint _amountSent = (msg.sender == buyer) ? buyerBalance : sellerBalance;
        if (msg.sender == buyer) {
            buyerBalance = 0;
            BuyerShareCollected(_amountSent);
        }
        else if (msg.sender == seller) {
            sellerBalance = 0;
            SellerShareCollected(_amountSent);
        }
        if (!msg.sender.send(_amountSent)) throw;
    }
}