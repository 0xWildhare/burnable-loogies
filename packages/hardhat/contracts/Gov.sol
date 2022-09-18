pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import './YourCollectible.sol';
import "hardhat/console.sol";

contract Gov is YourCollectible{

  uint public votingPeriodLength;
  uint public voteIdNumber; //voteIdNumber = ending timestamp of vote
  uint public passingVotePrecent;
  uint public votes;
  uint public lastPassingVote;
  uint golden = 1618033988749894848;

  bool public coolDown;

  struct Proposal {
    string name;
    uint proposerId;
    address to;
    uint value;
    bytes data;
  }

  //voteIdNumber (identifier for a specific vote) => the vote
  mapping (uint => Proposal) public proposals;
  //voteIdNumber  => id => has voted true/false
  mapping (uint => mapping (uint => bool)) private hasVoted;

  event VotePassed(string name, uint voteIdNumber , uint votes, uint votesRequired);
  event VoteFailed(string name, uint voteIdNumber , uint votes, uint votesRequired);

  constructor(uint _chainId) YourCollectible(_chainId) {
    votingPeriodLength = 3 minutes;
    passingVotePrecent = 34;
  }

  function closeVote() public {
    require(block.timestamp >= voteIdNumber , "vote not finished");
    uint votesRequired = totalSupply() * passingVotePrecent / 100;
    if(votes >= votesRequired) {
      coolDown = true; //cooldown only if it passed
      emit VotePassed(proposals[voteIdNumber ].name, voteIdNumber , votes, votesRequired);
      lastPassingVote = voteIdNumber ;
      voteIdNumber  = block.timestamp + votingPeriodLength; //cooldown period same length as voting period
    } else emit VoteFailed(proposals[voteIdNumber ].name, voteIdNumber , votes, votesRequired);
    votes = 0;
  }

  function executeVote() public returns (bytes memory) {
    require(coolDown, "no executable vote");
    require(block.timestamp >= voteIdNumber , "cooldown not finished");
    coolDown = false;
    Proposal memory p = proposals[lastPassingVote];
    console.log("proposal", p.to);
    bytes32 _hash =  getTransactionHash(nonce, p.to, p.value, p.data);
    nonce++;
    (bool success, bytes memory result) = payable(p.to).call{value: p.value}(p.data);
    require(success, "executeVote: tx failed");
    emit ExecuteTransaction(msg.sender, payable(p.to), p.value, p.data, nonce-1, _hash, result);
    return result;
  }

  function propose(uint _proposerId, string memory _name, address _to,  uint _value, bytes memory _data) public {
    require(_isApprovedOrOwner(_msgSender(), _proposerId), "ERC721: caller is not token owner nor approved");
    require(!coolDown, "cant propose during cooldown");
    require(block.timestamp >= voteIdNumber , "vote in progress");
    require(votes==0, "close prrevious vote");

    voteIdNumber = block.timestamp + votingPeriodLength;
    Proposal storage np = proposals[voteIdNumber];
    np.name = _name;
    np.proposerId = _proposerId;
    np.to = _to;
    np.value = _value;
    np.data = _data;

  }

  function voteYe(uint _id) public {
    require(_isApprovedOrOwner(_msgSender(), _id), "ERC721: caller is not token owner nor approved");
    require(!coolDown, "cant vote during cooldown");
    require(block.timestamp < voteIdNumber, "vote finished");
    require(hasVoted[voteIdNumber][_id]!=true, "id already voted");
    hasVoted[voteIdNumber][_id]=true;
    votes++;
  }

  function voteNah(uint _id) public {
    require(_isApprovedOrOwner(_msgSender(), _id), "ERC721: caller is not token owner nor approved");
    require(!coolDown, "cant vote during cooldown");
    require(block.timestamp < voteIdNumber, "vote finished");
    require(hasVoted[voteIdNumber][_id]!=true, "id already voted");
    hasVoted[voteIdNumber][_id]=true;
    votes--;
  }

}
