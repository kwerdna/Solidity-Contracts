pragma solidity 0.4.8;
// crowdfunded BOP (Burnable Open Payment)
// the 'artist' has an idea for a project but needs funding
// they create a contract which includes a message.
// min pledge amd min payment/burn amounts are optional
// after funders pledge eth they can only pay the artist or burn the eth
// each funder controls the amount of eth they have pledged
// the artist and funder(s) can communicate thru event/messages as the project progresses
// funders can pledge more funds at later stages in the project

contract goFundOrBurnIt {
    address artist = msg.sender;
    address constant burnAddress = 0xdead;
    uint minimumPledge;
    uint minimumPayment;
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

    function goFundOrBurnIt(string Message, uint minPledge, uint minPayment) 
        condition (minPledge >= minPayment)
    {
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
}