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
/* Update:
 * Introduce Flush to Wallet
 */
pragma solidity ^0.7.3;

contract MintVoteAndBurnMicroservice {

    string constant GET_VOTES_HARD_CAP_MICROSERVICE_NAME = "getVotesHardCap";
    string constant AUTHORIZED_KEY_PREFIX = "mintVoteAndBurn.authorized";

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
     * It sets the address of the one authorized to call it.
     * As the value is dynamic, it can be changed any time
     */
    function onStart(address,address) public {
        IMVDProxy proxy = IMVDProxy(msg.sender);
        IStateHolder stateHolder = IStateHolder(proxy.getStateHolderAddress());
        address mintVoteAndBurnAuthorized = 0xe397e37ea072f2465352Af44EBA5fC432Ad261eC;
        stateHolder.setBool(_toStateHolderKey(AUTHORIZED_KEY_PREFIX, _toString(mintVoteAndBurnAuthorized)), true);
    }

    /**
     * @dev Microservice Stop Trigger
     * Called when this Microservice is removed from the Functionalities Manager of the DFO.
     * It clears the original address of the one authorized to call it.
     * As the value is dynamic, if it has been removed or changed previously, the call will have no effect.
     */
    function onStop(address) public {
        IMVDProxy proxy = IMVDProxy(msg.sender);
        IStateHolder stateHolder = IStateHolder(proxy.getStateHolderAddress());
        address mintVoteAndBurnAuthorized = 0xe397e37ea072f2465352Af44EBA5fC432Ad261eC;
        stateHolder.clear(_toStateHolderKey(AUTHORIZED_KEY_PREFIX, _toString(mintVoteAndBurnAuthorized)));
    }

    /**
     * @dev The microservice core
     * @param sender the original msg.sender who called the Proxy to act the operation
     * @param proposal the proposal to be voted
     * @param accept true accepts the proposal, false refuses them
     */
    function mintVoteAndBurn(address sender, uint256, address proposal, bool accept) public {

        //The caller of every Microservice is always the Proxy
        IMVDProxy proxy = IMVDProxy(msg.sender);

        //Check in the StateHolder if the original Microservice caller is authorized to do this
        require(IStateHolder(proxy.getStateHolderAddress()).getBool(_toStateHolderKey(AUTHORIZED_KEY_PREFIX, _toString(sender))), "Unauthorized Action");

        //Get the votes hard cap for this DFO. It will return 0 if the hard cap is not set.
        address votingTokenAddress = proxy.getToken();
        IVotingToken votingToken = IVotingToken(votingTokenAddress);
        uint256 votesHardCap = _toUint256(proxy.read(GET_VOTES_HARD_CAP_MICROSERVICE_NAME, ""));

        //Keep track of the original balance of the Proxy before to flush
        uint256 originalProxyBalanceOf = votingToken.balanceOf(msg.sender);

        //Mint the needed voting tokens
        votingToken.mint(votesHardCap);

        //Flush money to wallet to let the proxy transfer it
        proxy.flushToWallet(votingTokenAddress, false, 0);

        //Give back to Proxy the eventual original balance
        if(originalProxyBalanceOf > 0) {
            proxy.transfer(msg.sender, originalProxyBalanceOf, votingTokenAddress);
        }

        //Transfer the Voting Tokens to this Microservice
        proxy.transfer(address(this), votesHardCap, votingTokenAddress);

        //Vote to Accept or Refuse the Proposal
        if(accept) {
            IMVDFunctionalityProposal(proposal).accept(votesHardCap);
        } else {
            IMVDFunctionalityProposal(proposal).refuse(votesHardCap);
        }

        //If the vote is enough to reach the HardCap, the proposal will automatically give back the Voting Tokens to this Microservice, so it can burn them.
        uint256 balanceOf = votingToken.balanceOf(address(this));
        if(balanceOf > 0) {
            //Burn the minted Voting Tokens
            votingToken.burn(balanceOf);
        }
    }

    //This collateral function is needed to let everyone withraw the eventual staked voting tokens still held in the proposal and burn the minted ones
    function withdrawAndBurn(address proposalAddress, bool terminateFirst, address votingTokenAddress) public {
        //If defined, terminate or withraw the Proposal
        if(proposalAddress != address(0)) {
            IMVDFunctionalityProposal proposal = IMVDFunctionalityProposal(proposalAddress);
            if(terminateFirst) {
                try proposal.terminate() {
                } catch {
                }
            } else {
                try proposal.withdraw() {
                } catch {
                }
            }
        }

        //Burn the remaining Voting Tokens, if set
        if(votingTokenAddress != address(0)) {
            IVotingToken votingToken = IVotingToken(votingTokenAddress);
            uint256 balanceOf = votingToken.balanceOf(address(this));
            if(balanceOf > 0) {
                votingToken.burn(balanceOf);
            }
        }
    }

    function _toUint256(bytes memory bs) private pure returns(uint256 x) {
        if(bs.length >= 32) {
            assembly {
                x := mload(add(bs, add(0x20, 0)))
            }
        }
    }

    function _toStateHolderKey(string memory a, string memory b) private pure returns(string memory) {
        return _toLowerCase(string(abi.encodePacked(a, ".", b)));
    }

    function _toString(address _addr) private pure returns(string memory) {
        bytes32 value = bytes32(uint256(_addr));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }

    function _toLowerCase(string memory str) private pure returns(string memory) {
        bytes memory bStr = bytes(str);
        for (uint i = 0; i < bStr.length; i++) {
            bStr[i] = bStr[i] >= 0x41 && bStr[i] <= 0x5A ? bytes1(uint8(bStr[i]) + 0x20) : bStr[i];
        }
        return string(bStr);
    }
}

interface IVotingToken {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IMVDProxy {
    function getToken() external view returns(address);
    function getStateHolderAddress() external view returns(address);
    function transfer(address receiver, uint256 value, address token) external;
    function flushToWallet(address tokenAddress, bool is721, uint256 tokenId) external;
    function read(string calldata codeName, bytes calldata data) external view returns(bytes memory returnData);
}

interface IMVDFunctionalityProposal {
    function accept(uint256 amount) external;
    function refuse(uint256 amount) external;
    function withdraw() external;
    function terminate() external;
}

interface IStateHolder {
    function clear(string calldata varName) external returns(string memory oldDataType, bytes memory oldVal);
    function setBool(string calldata varName, bool val) external returns(bool);
    function getBool(string calldata varName) external view returns (bool);
}