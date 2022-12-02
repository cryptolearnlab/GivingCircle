// ATXDAO Giving Circle by tlogs.eth via Crypto Learn Lab
// SPDX-License-Identifier: all rights reserved

pragma solidity ^0.8.10;

interface USDCcontract {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

abstract contract ATXDAOgivingCircle {

// STATE VARIABLES

USDCcontract public USDC; // implement USDC ERC20 interface with USDC contract address in constructor

address public circleleader; //needed to start first circle, set in constructor, used in all modifiers

uint public totalUSDCgifted; // decimals = 0

uint public totalUSDCpending; // decimals = 0

uint public totalBeans; // decimals = 0

uint public USDCperCircle; // initially 1000 USDC per circle. decmials = 0 (multiplied by weiMultiplier in all calcs)

uint public weiMultiplier; // utilized in various calcs to convert to ERC20 decimals

// are these redundant? YES needed uint[] arrays for various 'for' loops over proposals & circles

uint[] public checkforProp; // utilized to check if prop exists. array of all proposal numbers

uint[] public checkforCircle; // utilized to check if giving cricle exists. array of all circle numbers

// STRUCTS

struct Proposal {
    uint beansReceived;
    address payable giftAddress;
}

struct GivingCircle {
    bool propWindowOpen; // set to true upon creating circle
    uint USDCperBean; // 
    bool votingOpen; // closePropWindow sets propWindow open to false and sets votingOpen to true

    bool beansDisbursed; // implement to initiatlly be false, but flipped to true when disburseBeans function is run.
    address circleLeader;
    uint[] proposalsincircle;
}

// MAPPINGS

mapping (address => uint) beanBalances; // beanBalances have decimals of 0. tracks outstanding votes from all circles attended.

mapping (address => uint) public USDCgiftPending; // beanBalances have decimals of 10**18, always mirror changes in totalUSDCpending when changing mapping.

mapping (address => uint) public USDCgiftsReceived; // tracks total gifts withdrawn by proposers, decimals = 0

mapping (uint => GivingCircle) public circleNumbers; // give each circle a number. uint replicated in checkforCircle array.

mapping (uint => Proposal) public proposalNumbers; // give each proposal a number. uint replicated in checkforProp array.

mapping (uint => uint[]) proposalsInCircle; // circle > proposals one-to-many. 

mapping (address => uint[]) circlesAttended; // to track the circle numbers each DAO member has attended.
 
// EVENTS



// CONSTRUCTOR 

    constructor(address _usdc, address _circleleader) {
    USDC = USDCcontract(_usdc); // set usdc contract address
    circleleader = _circleleader; // set the first circle leader
    weiMultiplier = 10**18;  // set weiMultiplier to convert between ERC-20 decimal = 10**18 and decimal 0
    USDCperCircle = 1000; // set initial USDCperCircle. to be multiplied by weiMultiplier in all ERC20 calls
    }

// UTILITY FUNCTIONS


    // @tlogs: Returns the address of the current circleLeader.


    function circleLeader(uint _circle) public view virtual returns (address) {
        return circleNumbers[_circle].circleLeader;
    }


    // @tlogs: Check if a proposal exists, used before allowing for new proposal creation via proposeGift

    function proposalExists(uint propnum) public view returns (bool) {
        for (uint i = 0; i < checkforProp.length; i++) {
            if (checkforProp[i] == propnum) {
            return true;
            }
        }
        return false;
    }

    // @tlogs: Check if a Giving Circle already exists at creation

    function circleExists(uint circlenum) public view returns (bool) {
        for (uint i = 0; i < checkforCircle.length; i++) {
            if (checkforCircle[i] == circlenum) {
            return true;
            }
        }
        return false;
    }

// add a for loop so proposalWindowOpen can receive all proposalNumbers from a circle in uint[] array then check if any exist in proposalNumbers mapping

    function proposalWindowOpen (uint _checkcircle) public virtual returns (bool) {
        require (
            circleNumbers[_checkcircle].propWindowOpen == true, "Giving Circle is not open for proposal submission"
        );
        return true;
    }
    function votingOpen (uint checkcircle) public virtual returns (bool) {
        require (
            circleNumbers[checkcircle].votingOpen == true, "Giving Circle is not open for bean placement"
        );
        return true;
    }

    function onlyGiftee (uint proposalNumber) internal virtual returns (bool) {
    require (
        proposalNumbers[proposalNumber].giftAddress == msg.sender, "this is not your gift!"
    );
    return true;
    }
// ADMIN FUNCTIONS

    // @tlogs: will return total USDC gifts withdrawn in decimal=0 in addition to an array of all props submitted
        // FIX propfundings array is currently returning beansReceived


    function getgiftrecords (address recipient) public view returns (uint, uint[] memory, uint[] memory) {
        uint[] memory propsposted = new uint[](checkforProp.length);
        uint[] memory propfundings = new uint[](checkforProp.length);
        uint recipientGifts = USDCgiftPending[recipient];
    for (uint i = 0; i < checkforProp.length; i++) {
        if (proposalNumbers[checkforProp[i]].giftAddress == recipient) {        // checks for props where address is gift recipient
            propsposted[i] = checkforProp[i];
            propfundings[i] = proposalNumbers[i].beansReceived;
            }
        return (recipientGifts, propsposted, propfundings);   
    }
    }

// CIRCLE LEADER FUNCTIONS

    // @tlogs: only the current circle leader can set a new circle leader for currently open circle,
    //        else, the current circle leader becomes circle leader for next circle.
    //            add an event emission for change in circle leader

    function newCircleLeader(address newLeader) public view returns (address) {
        require (
            circleleader == msg.sender, "only circle leader can elect new leader"
        );
        circleleader == newLeader;
        return circleleader;
    }

    // @tlogs: create event emission for creating a new circle
    // true:false established for propWindowOoen:votingOpen upon Giving Circle creation (redemption conditions not met)

    function newCircle(uint _circlenumber) public payable returns (bool) {
        require(
           circleleader == msg.sender, "only circle leader can start a new circle"
        );
        require(
            circleExists(_circlenumber) == false, "giving circle already exists" // runs a for loop on checkforCircle array, will return true if duplicate
        );

        checkforCircle.push(_circlenumber); // add the circle number to the checkforCircle array.
        GivingCircle storage g = circleNumbers[_circlenumber]; 
        g.USDCperBean = _calcUSDCperBean(_circlenumber); // run the _setUSDCperBean internal command 
        g.propWindowOpen = true; // set propWindowOpen to true in order to allow for proposals to be submitted to the new giving circle.
        g.votingOpen = false; // prevent voting while proposal submission window is open.
        g.beansDisbursed = false;
        g.circleLeader = circleleader; // record circle leader at the time of the circle. 
        return (true); // need an else false statement?

    }

    // called by Circle Leader to close a Giving Circle to additional propositions. Triggers votingOpen in preparation for bean distribution. 
    // It doesn't matter if people start voting with accrued beans before distribution when new beansPerUSDC is set, as long as USDCperBean is set before gifts are redeemed are enabled.
    // false:true established for propWindowOoen:votingOpen upon Giving Circle creation (redemption conditions not met)

    function closePropWindow(uint closeCircleNumber) public returns (bool) {
        require(
           circleleader == msg.sender, "only circle leader can start a new circle"
        );
        require(
           circleNumbers[closeCircleNumber].propWindowOpen == true , "circle is not currently open to proposals"
        );    
        circleNumbers[closeCircleNumber].propWindowOpen = false;
        circleNumbers[closeCircleNumber].votingOpen = true;
        return true;
    }



    // @tlogs:      needs work, considering making an intern
    //        need a modifier to restrict disburseBeans to onlyOwner & open circles
    //       consider making this an internal function called by closePropWindow
    //     disburseBeans is the only function that should affect USDCperBea 

    function disburseBeans(uint disburseforCircleNumber, address[] memory attendees) public payable virtual returns (bool) {
            require (
                circleleader == msg.sender, "only circle cleader can disburse beans"    // only the circle leader can disburse beans
            );
            require (
                USDC.balanceOf(msg.sender) >= USDCperCircle, "not enough USDC to start circle" // checks if circle leader has at least USDCperCircle 
            );
            require (
                circleNumbers[disburseforCircleNumber].beansDisbursed == false, "beans already disbursed!" // beans can only be disbursed once per circle
            );

            USDC.approve(msg.sender, USDCperCircle * weiMultiplier); // insure approve increases circle leader allowance

            // input a check to await confirmation of approve function before calling transferFrom.

            USDC.transferFrom(msg.sender, address(this), USDCperCircle * weiMultiplier); // transfer USDC to the contract
       
            // input a check that awaits transfer event before allowing for circle to be created.

            address[] memory disburseTo = attendees;
            for (uint i = 0; i < disburseTo.length; i++) // for loop to allocate attendee addresses +10 beans
            beanBalances[disburseTo[i]] += 10; // change to beanBalances should be mirrored by totalbeans change below
            totalBeans += (10 * disburseTo.length); // affects USDCperBean.
            circleNumbers[disburseforCircleNumber].beansDisbursed = true; // set beansDisbursed to true for disburseforCircleNumber
            _calcUSDCperBean(disburseforCircleNumber); // make sure this is correct
            return true;
    }

    // used by circleLeader to end giving circle after all beans have been placed
    // triggers _allocateGifts internal function
    // false:false established for propWindowOoen:votingOpen upon Giving Circle creation (redemption condition met)

    function closeCirclevoting(uint endcirclenumber) public virtual returns (bool) {
        require (
            circleLeader(endcirclenumber) == msg.sender, "caller is not CircleLeader"
        );
        require (
            circleNumbers[endcirclenumber].votingOpen = true, "giving circle voting is not open"
        );
        circleNumbers[endcirclenumber].votingOpen = false;
        _allocateGifts(endcirclenumber);
        return true;
    }

// PROPOSER FUNCTIONS

    function proposeGift(uint propNumber, uint proposeInCircle, address payable giftRecipient) public virtual returns (bool) {
        require(
            proposalExists(propNumber) == false, "selected gift proposal number already exists."
        );
        require(
            proposalWindowOpen(proposeInCircle) == true, "selected giving circle is not open for gift proposals" // requires a circle's propWindowOpen boolean to be true
        );
        checkforProp.push(propNumber); // add the gift proposal number to overall gift proposal check
        proposalsInCircle[proposeInCircle].push(propNumber); // add the gift proposal to array within proposalsInCircle array within Giving Circle struct
        Proposal storage p = proposalNumbers[propNumber]; // used to push Proposal Struct elements to proposalNumbers mapping below
        p.beansReceived = 0;
        p.giftAddress = giftRecipient;
        circleNumbers[proposeInCircle].proposalsincircle.push(propNumber); // maps the proposal to the Giving Circle currently open
        return true;   
    }

    //**
    // * @tlogs: consider adding an event for a gift redemption.
            /* since USDCgiftPending mapping is 10**18, redemptionqty is 10**18
            /* only redeem whole number USDC
            /* consider adding a return element
     */
    // double false required on proposalWindowOpen & votingOpen.

    function redeemGift(uint proposedincirclenumber, uint proposal) external virtual {
        require(
            onlyGiftee(proposal), "not your gift! nice try :]"
        );
        require( //consider a for loop function which iterates over uint[] returned by proposalsInCircle
            proposalWindowOpen(proposedincirclenumber) == false, "selected giving circle is still accepting proposals" // proposalsInCircle returns uint[] of return circle
        );
        require(
            votingOpen(proposedincirclenumber) == false, "selected giving circle is still accepting votes"
        );
        
        uint256 redemptionqty = USDCgiftPending[msg.sender]; // will be 10**18
        USDCgiftPending[msg.sender] = 0;
        address payable giftee = proposalNumbers[proposal].giftAddress;
        totalUSDCpending -= redemptionqty / weiMultiplier; // reduce pending gifts by redeemed amount
        totalUSDCgifted += redemptionqty / weiMultiplier; // divide by weiMultiplier to give whole number totalUSDCgifted metric
        USDCgiftsReceived[msg.sender] += redemptionqty / weiMultiplier; // updates mapping to track total gifts withdrawn from contract
        USDC.transferFrom(address(this), giftee, redemptionqty); // USDCgiftPending mapping is 10**18, thus so is redemptionqty
    }

// BEAN HOLDER FUNCTIONS

    function checkbeanBalance (address beanholder) external virtual returns (uint) {
        return beanBalances[beanholder];
    }

    //**
    // * @tlogs: consider adding an event for beans placed.
    // */

    function placeBeans (uint circlenumb, uint propnumber, uint beanqty) external virtual returns (bool) {
        require (
            votingOpen(circlenumb) == true, "giving circle is closed to voting"
        );
        require (
            beanBalances[msg.sender] >= beanqty, "not enough beans held to place beanqty"
        );
        beanBalances[msg.sender] -= beanqty;
        totalBeans -= beanqty;
        proposalNumbers[propnumber].beansReceived += beanqty;
        return true;
    }

// INTERNAL FUNCTIONS

     // @tlogs: availableUSDC multiplies denominator by weiMultiplier to mitigate rounding errors due to uint

    function _calcUSDCperBean (uint256 circle_) internal virtual returns (uint) {
        uint256 availableUSDC = USDC.balanceOf(address(this)) - (totalUSDCpending * weiMultiplier); // availableUSDC is 10**18
        uint256 newusdcperbean = (availableUSDC) / totalBeans; // numberator is large due to weiMultipler, total beans is decimal = 0.
        circleNumbers[circle_].USDCperBean = newusdcperbean;
        return newusdcperbean; // availableUSDC is 10**18, thus minimizing rounding with small totalBeans uint (not 10**18).
    }

    // @tlogs: 
    //         USDCperBean is 10**18 
    //         thus allocate will be 10**18 
    //         thus USDCgiftPending mapping will be 10**18

    function _allocateGifts (uint allocateCircle) internal virtual returns (bool) {
            
            uint256 useUSDCperBean = circleNumbers[allocateCircle].USDCperBean;

        for (uint i = 0; i < proposalsInCircle[allocateCircle].length; i++) {
            uint256 allocate = proposalNumbers[i].beansReceived * useUSDCperBean; // beans received is decimal 0, USDCperBean is decimal 10**18, thus allocate is 10**18
            USDCgiftPending[proposalNumbers[i].giftAddress] += allocate; // utilizes 10**18
            totalUSDCpending += allocate / weiMultiplier; // ensure proper decimal usage here, desired is decimals = 0 
        }
            return true;
    }

    }