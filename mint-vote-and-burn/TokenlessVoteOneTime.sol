//SPDX-License-Identifier: MIT

/* Discussion:
 * https://github.com/b-u-i-d-l/dfo-hub
 */
/* Description:
 * Mint, Vote and Burn
 * This DFO Miscroservice is useful to let any authorized entity to automatically accept or refuse a Proposal of this DFO using Voting Tokens that do not impact the available supply.
 * In fact, before to vote, the DFO mints the necessary votes to reach the Hard Cap, vote the proposal, then automatically burn them after the vote in just a single atomic action.
 * For reasons of precaution, if something goes wrong with the vote, the Microservice has a backup functionality that will let everyone terminate the proposal and burn all the voting tokens.
 */
pragma solidity ^0.7.3;

contract TokenlessVoteOneTime {

    string private constant TOKENLESS_VOTE_MICROSERVICE_NAME = "tokenlessVote";

    address private constant PROPOSAL_ADDRESS = 0x198A71E2E0f86829DA6927FEdC930c530175C9d9;
    bool private constant ACCEPT = true;

    string private _metadataLink;

    constructor(string memory metadataLink) {
        _metadataLink = metadataLink;
    }

    function getMetadataLink() public view returns(string memory) {
        return _metadataLink;
    }

    function callOneTime(address) public {
        IMVDProxy(msg.sender).submit(TOKENLESS_VOTE_MICROSERVICE_NAME, abi.encode(address(0), 0, IMVDFunctionalityProposal(PROPOSAL_ADDRESS).getProxy(), PROPOSAL_ADDRESS, ACCEPT));
    }
}

interface IMVDProxy {
    function submit(string calldata codeName, bytes calldata data) external payable returns(bytes memory returnData);
}

interface IMVDFunctionalityProposal {
    function getProxy() external view returns(address);
}