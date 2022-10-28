//SPDX-License-Identifier: Unlicensed

/// @author Bhumi Sadariya

pragma solidity 0.8.13;

import {IFakeDAI} from "./IFakeDAI.sol";

import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

// For deployment on Ploygon Testnet
contract Funding {
    // mapping of funder's address to different projects(project owner's addresses)
    mapping(address => address[]) public userToProjects;

    //mapping to check whether the stream for a particular project is open or not.
    mapping(address => mapping(address => bool)) public isStreamOpen;
    mapping(address => uint256) public userToAmount;

    //For superfluid
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1; //initialize cfaV1 variable

    mapping(address => bool) public accountList;

    ISuperToken public polygonDaiX;

    // Host address on Polygon = 0xEB796bdb90fFA0f28255275e16936D25d3418603
    // fDAIx address on Polygon = 0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f
    constructor(ISuperfluid _host, ISuperToken _polygonDaiX) {
        //initialize InitData struct, and set equal to cfaV1
        cfaV1 = CFAv1Library.InitData(
            _host,
            //here, we are deriving the address of the CFA using the host contract
            IConstantFlowAgreementV1(
                address(
                    _host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );

        polygonDaiX = _polygonDaiX;
    }

    /// @dev Mints 10,000 fDAI to this contract and wraps it all into fDAIx
    function gainDaiX() external {
        // Get address of fDAI by getting underlying token address from DAIx token
        IFakeDAI fdai = IFakeDAI(polygonDaiX.getUnderlyingToken());

        // Mint 10,000 fDAI
        fdai.mint(address(this), 10000e18);

        // Approve fDAIx contract to spend fDAI
        fdai.approve(address(polygonDaiX), 20000e18);

        // Wrap the fDAI into fDAIx
        polygonDaiX.upgrade(10000e18);
    }

    /// @dev creates a stream from this contract to desired receiver at desired rate
    function startFunding(address receiver, int96 flowRate) external {
        // int96 flowRate =1000000;
        // Create stream
        cfaV1.createFlow(receiver, polygonDaiX, flowRate);
        userToProjects[msg.sender].push(receiver);
        isStreamOpen[msg.sender][receiver] = true;
    }

    /// @dev deletes a stream from this contract to desired receiver
    function stopFunding(address receiver) external {
        // Delete stream
        cfaV1.deleteFlow(address(this), receiver, polygonDaiX);
        isStreamOpen[msg.sender][receiver] = false;
    }

    /// @dev stake matic and get fdaix in return, for now 1 matic= 1 fdaix
    function getDAIx(uint256 amount) public payable {
        // require(msg.value == amount, "it is not equal");
        payable(msg.sender).transfer(amount);
        userToAmount[msg.sender] += amount;
        polygonDaiX.transfer(msg.sender, amount);
    }

    /// @dev check the balance of fdaix token.
    function getBalance() public view returns (uint256) {
        uint256 amount = polygonDaiX.balanceOf(msg.sender);
        return amount;
    }
}
