pragma solidity ^0.4.18;


/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint256 a, uint256 b) pure internal returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) pure internal returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) pure internal returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) pure internal returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) pure internal returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) pure internal returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) pure internal returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) pure internal returns (uint256) {
    return a < b ? a : b;
  }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
      require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }

}


 /**
 * ERC223 token by Dexaran
 *
 * https://github.com/Dexaran/ERC223-token-standard
 */


contract ERC20 {
    function totalSupply()  public constant returns (uint256 supply);
    function balanceOf( address who )  public constant returns (uint256 value);
    function allowance( address owner, address spender )  public constant returns (uint256 _allowance);

    function transfer( address to, uint256 value)  public returns (bool ok);
    function transferFrom( address from, address to, uint256 value)  public returns (bool ok);
    function approve( address spender, uint256 value )  public returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint256 value);
    event Approval( address indexed owner, address indexed spender, uint256 value);
}
 
 contract ContractReceiver {
     function tokenFallback(address _sender,
                       uint256 _value,
                       bytes _extraData) public returns (bool);
 }
 

contract Proposal is ContractReceiver {
    using SafeMath for uint256;

    event TokenFallback(address _sender,
                       uint256 _value,
                       bytes _extraData);

    address public mainContract;
    /**
    * @dev Throws if called by any account other than the main contract.
    */
    modifier onlyMainContract() {
        require(msg.sender == mainContract);
        _;
    }

    Vote[] public votes;
    uint256 public goal;
    uint256 public progress;
    string public description;

    address public token;
    uint public periodInMinutes;
    uint public votingDeadline;

    // Proposal current status
    enum Status { Voting, Success, Failed }
    Status public status = Status.Voting;

    // Proposal document url
    string public documentUrl;
    string public documentHash;

    // Proposal delivery document url
    string public deliveryDocUrl;
    string public deliveryDocHash;

    // Proposal delivery status
    enum DeliveryStatus { Waiting, Sent, Failed }
    DeliveryStatus public deliveryStatus = DeliveryStatus.Waiting;

    struct Vote {
        address voter;
        uint256 amount;
    }

    /**
     * Add Proposal
     *
     * Propose to send KATIN Token for voting
     *
     * @param _token address of KATIN Coin
     * @param _goal Amount of KATIN Coin goal
     * @param _description Description of proposal
     * @param _periodInMinutes Goal deadline in minutes
     * @param _documentUrl Document url
     * @param _documentHash Document hash
     */
    function Proposal(
        address _mainContract,
        address _token,
        uint256 _goal,
        string _description,
        uint _periodInMinutes,
        string _documentUrl,
        string _documentHash
    )
        public
    {
        mainContract = _mainContract;
        token = _token;
        goal = _goal;
        description = _description;
        periodInMinutes = _periodInMinutes;
        votingDeadline = now + _periodInMinutes * 1 minutes;
        documentUrl = _documentUrl;
        documentHash = _documentHash;
    }

    // Need action: check to only accept KATIN Token
    function tokenFallback(address _sender,
                       uint256 _value,
                       bytes _extraData) public returns (bool) {
        require(status == Status.Voting);
        require(token == msg.sender);
        require(now <= votingDeadline);
        require(goal >= progress.add(_value));

        uint voteID = votes.length++;
        votes[voteID] = Vote({voter: _sender, amount: _value});

        progress = progress.add(_value);

        if (goal == progress) {
            status = Status.Success;
        }

        TokenFallback(_sender, _value, _extraData);
    }

    function verify() public {
        require(status == Status.Voting);

        // Passed deadline
        if (now > votingDeadline) {
            if(progress < goal) {
                status = Status.Failed;
                returnTokens();
            } else {
                status = Status.Success;
            }
        }
    }

    // Return all tokens to participants
    function returnTokens() private {
        ERC20 katinCoin = ERC20(token);
        for (uint i = 0; i <  votes.length; ++i) {
            Vote storage v = votes[i];
            
            
            katinCoin.transfer( v.voter, v.amount);
        }
    }

    function voteBy(address _voter) public view returns (uint256) {
        uint256 amount = 0;
        for (uint i = 0; i <  votes.length; ++i) {
            // Todo: may change to memory
            Vote memory v = votes[i];
            if (v.voter == _voter) {
                amount = amount.add(v.amount);
            }
        }
        return amount;
    }

    /**
     * Update delivery state
     *
     * Main contract update delivery state when sent or failed
     *
     * @param _documentUrl document url for delivery confirmation
     * @param _documentHash document hash with sha3
     * @param _status delivery status
     */
    function updateDelivery(string _documentUrl, string _documentHash, DeliveryStatus _status) public onlyMainContract returns (bool) {
        deliveryDocUrl = _documentUrl;
        deliveryDocHash = _documentHash;
        deliveryStatus = _status;

        return true;
    }

    function voteCount() public view returns (uint256) {
        return votes.length;
    }
}


contract Main is Ownable {
    using SafeMath for uint256;

    event EtherReceive(address _sender,
                        uint256 _value);

    
    // list of proposals, including ongoing, success and failed proposals
    address[] public proposals;

    /**
     * Ether receivable
     */
	function() payable public {
        EtherReceive(msg.sender, msg.value);
    }

    /**
        @dev list a pre-created proposal
        throws on any error rather then return a false flag to minimize user errors

        @param _proposal proposal address

        @return true if there's a compatible proposal, false if it wasn't
    */
    function acceptProposal(address _proposal) public onlyOwner returns (bool) {
        // TODO: Check if correct proposal
        proposals.push( _proposal );
        return true;
    }

    /**
        @dev Mark a proposal as delivered
        throws on any error rather then return a false flag to minimize user errors

        @param _index index of proposal
        @param _documentUrl document that prove of delivered
        @param _documentHash sha3 hash of _documentUrl

        @return true if success, false if it wasn't
    */
    function updateProposalDeliverySuccess(uint256 _index, string _documentUrl, string _documentHash) public onlyOwner returns (bool) {
        Proposal proposal = Proposal(proposals[_index]);
        require(Proposal.Status.Success == proposal.status());

        return proposal.updateDelivery(_documentUrl, _documentHash, Proposal.DeliveryStatus.Sent);
    }

    /**
        @dev Mark a proposal as failed to deliver
        throws on any error rather then return a false flag to minimize user errors

        @param _index index of proposal
        @param _documentUrl document that prove of failed to deliver
        @param _documentHash sha3 hash of _documentUrl

        @return true if success, false if it wasn't
    */
    function updateProposalDeliveryFailed(uint256 _index, string _documentUrl, string _documentHash) public onlyOwner returns (bool) {
        Proposal proposal = Proposal(proposals[_index]);
        require(Proposal.Status.Success == proposal.status());

        return proposal.updateDelivery(_documentUrl, _documentHash, Proposal.DeliveryStatus.Failed);
    }

    function proposalCount() public view returns (uint256) {
        return proposals.length;
    }

    function newProposal(
        address _mainContract,
        address _token,
        uint256 _goal,
        string _description,
        uint _periodInMinutes,
        string _documentUrl,
        string _documentHash
    )
        public onlyOwner returns (bool)
    {
        address newProposalAddr = address(new Proposal(_mainContract, _token, _goal, _description, _periodInMinutes, _documentUrl, _documentHash));
        acceptProposal(newProposalAddr);
        return true;
    }
}