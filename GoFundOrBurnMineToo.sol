// crowdfunded BOS (Burnable Open Service)
// the 'artist' has an idea for a project but needs funding
// they create a contract which includes a message.
// min pledge amd min payment/burn amounts are optional.
// after funders pledge eth they can only pay the artist or burn the eth.
// each funder controls the amount of eth they have pledged.
// the artist and funder(s) can communicate thru event/messages as the project progresses.
// funders can pledge more funds at any time.
//
// new
// the artist stakes ether in the contract which is locked until
// the artist has been paid an amount >= artistDownPayment * payoutFactor.
// once this condition is met the artist can withdraw their stake.
// artistHasStake is set to false when the artist withdraws the down payment.
// a timeDeadline is set during construction.
// any funder with a balance >= artistDownPayment may burn the artistDownPayment
// if the deadline passes and the artist has not reached the requirement for stake withdrawal.
// an equal amount of funds controlled by the funder are also burned.
//
// new
// unclaimedFunds : running total of eth sent to the contract with no data.
// this can be withdrawn by artist after meeting requirement for stake withdrawal.
// unclaimed funds may be burned by funders if the same 
// conditions for burning artist funds are met.
//
pragma solidity 0.4.8;
contract goFundOrBurnMineToo {
    address artist = msg.sender;
    address constant burnAddress = 0xdead;
    uint minimumPledge;
    uint minimumPayment;
    // the artist stake is locked until
    // totalPaidToArtist >= artistFunds * payoutFactor 
    // to burn the artist stake after the deadline
    // a funder must have at least as much at stake as the artist
    bool public artistHasStake;
    uint public artistDownPayment;
    uint totalPaidToArtist;
    // payout factor and deadline are hardcoded in this example
    // but could be specified during contract contstruction
    uint8 payoutFactor = 3;
    // set a short time for testing
    uint timeDeadline = now + 10 minutes;

    // keep track of any eth sent with no data "unclaimed donations"
    uint public unclaimedFunds;

    mapping (address => uint) funder;
 
    modifier condition(bool c) {if (!c) throw; _;  }
    modifier onlyArtist() { if (msg.sender != artist) throw; _;}
    modifier onlyFunder() { if (funder[msg.sender] <= 0) throw; _;}

    event RequestMade(address Artist, string Message, uint MinPledge, uint MinPayment);
    event FundsPledged(address Funder, string Message, uint Amount, uint FundersBalance);
    event ArtistSentMessage(string Message);
    event FunderSentMessage(address funder, string Message, uint FundersBalance);
    event ArtistPaid(address Funder, uint Amount, string Message, uint FundersBalance);
    event FundsBurned(address Funder, uint Amount, string Message, uint FundersBalance);
    event ArtistWithdrewStake(uint Amount);
    event ArtistStakeBurned(address Funder, uint Amount);
    event ReceivedUnclaimedFunds(address Sender, uint Amount);

    function () payable {
        unclaimedFunds += msg.value;
        ReceivedUnclaimedFunds(msg.sender, msg.value);
    }

    function goFundOrBurnMineToo(string Message, uint minPledge, uint minPayment) 
        payable
        condition (minPledge >= minPayment)
    {
        if (msg.value > 0) {
            artistDownPayment = msg.value;
            artistHasStake = true;
        }    
        minimumPledge = minPledge;
        minimumPayment = minPayment;
        RequestMade(msg.sender, Message, minPledge, minPayment);
    }

    function pledgeFunds(string Message)
        payable
        condition(msg.sender != artist)
        condition(msg.value >= minimumPledge)
    {
        funder[msg.sender] += msg.value;
        FundsPledged(msg.sender, Message, msg.value, funder[msg.sender]);
    }

    function artistSendMessage(string Message) onlyArtist {
        ArtistSentMessage(Message);
    }

    function funderSendMessage(string Message) onlyFunder {
        FunderSentMessage(msg.sender, Message, funder[msg.sender]);
    }

    function payArtist(uint _amount, string Message)
        onlyFunder
        condition(funder[msg.sender] >= _amount)
        condition(_amount >= minimumPayment)
    {
        funder[msg.sender] -= _amount;
        if (artistHasStake) totalPaidToArtist += _amount;
        ArtistPaid(msg.sender, _amount, Message, funder[msg.sender]);
        if (!artist.send(_amount)) throw;
    }

    function burnFunds(uint _amount, string Message)
        onlyFunder
        condition(funder[msg.sender] >= _amount)
        condition(_amount >= minimumPayment)
    {
        funder[msg.sender] -= _amount;
        FundsBurned(msg.sender, _amount, Message, funder[msg.sender]);
        if (!burnAddress.send(_amount)) throw;
    }

    function withdrawArtistStake()
        onlyArtist
        condition(totalPaidToArtist >= artistDownPayment * payoutFactor)
        condition(artistHasStake)
    {
        artistHasStake = false;
        ArtistWithdrewStake(artistDownPayment);
        if (!artist.send(artistDownPayment)) throw;
    }

   function burnArtistStake()
        onlyFunder
        condition(artistHasStake)
        condition(now >= timeDeadline)
        condition(funder[msg.sender] >= artistDownPayment)
        condition(totalPaidToArtist < artistDownPayment * payoutFactor)
    {
        artistHasStake = false;
        ArtistStakeBurned(msg.sender, artistDownPayment);
        if (!burnAddress.send(artistDownPayment)) throw;
        burnFunds(artistDownPayment, 'Match burned artist stake');
    }

    function withdrawUnclaimed(uint _amount)
        onlyArtist
        condition(now >= timeDeadline)
        condition(totalPaidToArtist >= artistDownPayment * payoutFactor)
        condition(unclaimedFunds >= _amount)
    {
        unclaimedFunds -= _amount;
        ArtistPaid(artist, _amount, 'From unclaimed funds', unclaimedFunds);
        if (!artist.send(_amount)) throw;
    }

    function burnUnclaimed(uint _amount)
        onlyFunder
        condition(now >= timeDeadline)
        condition(funder[msg.sender] >= _amount)
        condition(totalPaidToArtist < artistDownPayment * payoutFactor)
    {
        unclaimedFunds -= _amount;
        FundsBurned(msg.sender, _amount, 'Unclaimed funds', unclaimedFunds);
        if (!burnAddress.send(_amount)) throw;
        burnFunds(_amount, 'Match burned unclaimed funds');
    }
}
