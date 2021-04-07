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

contract TokenlessVoteMicroservice {

    string constant MINT_VOTE_AND_BURN_MICROSERVICE_NAME = "mintVoteAndBurn";

    string private _metadataLink;

    constructor(string memory metadataLink) {
        _metadataLink = metadataLink;
    }

    function getMetadataLink() public view returns(string memory) {
        return _metadataLink;
    }

    /**
     * @dev Microservice Start Trigger
     * Called when this Microservice is set in the Functionalities Manager of the DFO.
     * Its body can be blank, but the function is mandatory
     */
    function onStart(address,address) public {
    }

    /**
     * @dev Microservice Stop Trigger
     * Called when this Microservice is removed from the Functionalities Manager of the DFO.
     * Its body can be blank, but the function is mandatory
     */
    function onStop(address) public {
    }

    /**
     * @dev The microservice core
     */
    function tokenlessVote(address sender, uint256, address proxyDFO, address proposal, bool accept) public {
        IMVDProxy proxy = IMVDProxy(msg.sender);
        require(IMVDFunctionalitiesManager(proxy.getMVDFunctionalitiesManagerAddress()).isAuthorizedFunctionality(sender), "Unauthorized Action!");
        IMVDProxy(proxyDFO).submit(MINT_VOTE_AND_BURN_MICROSERVICE_NAME, abi.encode(address(0), 0, proposal, accept));
    }
}

interface IMVDProxy {
    function getMVDFunctionalitiesManagerAddress() external view returns(address);
    function submit(string calldata codeName, bytes calldata data) external payable returns(bytes memory returnData);
}

interface IMVDFunctionalitiesManager {
    function isAuthorizedFunctionality(address functionality) external view returns(bool);
}