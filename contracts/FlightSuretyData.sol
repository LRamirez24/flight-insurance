pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyApp.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256 private authorizedAirlinesCount = 0;
    uint256 private changeAuthorizedVotes = 0;
    address private insuranceAccount;
    uint256 private insuranceBalance = 0;

    //Variables for airline
    

     struct Flight {
        uint8 statusCode;
        uint256 updatedTimestamp;        
        //address airline;
         Airline airline;
        string flight;
    }
        struct Airline { 
        string name;
        address account;
        bool isRegistered;
        bool isAuthorized;
        bool operationalVote;
        

    }
    struct Insurance{
        address account;
        uint256 insuranceAmount;
        uint256 payoutBalance;
    }

    mapping(address => uint256) private funding;
    mapping(bytes32 => Flight) private flights;
    mapping(address => Airline) airlines; 
    mapping(address => Insurance)private insurances; 
    mapping(address => uint256) private creditBalance;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event RegiteredAirline(address airline);
    event AuthorizedAirline(address airline);
    event BoughtInsurance(address caller, bytes32 key,uint256 amount);
    event CreditInsurance(address airline, address insurance, uint256 amount);
    event PayInsuree(address airline, address insurance, uint256 amount);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        //First airline is registered when contract is deployed.

           airlines[contractOwner] = Airline({
                    name: "Default Airline",
                    account: contractOwner,
                    isRegistered: true,
                    isAuthorized: true,
                    operationalVote: true

                    });

        authorizedAirlinesCount = authorizedAirlinesCount.add(1);
        emit RegiteredAirline(contractOwner);

    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */

      modifier requireIsAuthorized()
    {
        require(airlines[msg.sender].isAuthorized, "Airline needs to be authorized");
        _;
    }


    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
            if (authorizedAirlinesCount < 4) {
          operational = mode;
        } else { //use multi-party consensus amount authorized airlines to reach 50% aggreement
          changeAuthorizedVotes = changeAuthorizedVotes.add(1);
          airlines[caller].operationalVote = mode;
          if (changeAuthorizedVotes >= (authorizedAirlinesCount.div(2))) {
            operational = mode;
            changeAuthorizedVotes = authorizedAirlinesCount - changeAuthorizedVotes;
          }
        }
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                string name,
                                address airline
                            )
                            external
                            requireIsOperational
                            
    {
         require(!airlines[airline].isRegistered,"airline cant already be registered");
          if(authorizedAirlinesCount <= 4){
          airlines[airline] = Airline({
                      name: name,
                      account: airline,
                      isRegistered: true,
                      isAuthorized: false,
                      operationalVote: true
                      });
         authorizedAirlinesCount = authorizedAirlinesCount.add(1);
        }

        
        emit RegiteredAirline(airline);
    }

    function isAirline(address airline)public returns (bool)
    {
        return airlines[airline].isRegistered;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (    
                                address airline,     
                                address insurance, 
                                string flight,
                                uint256 timeStamp,
                                uint256 amount                         
                            )
                            requireIsOperational
                            external
                            payable
    {
        require(insurances[insurance].account == insurance,"need to provide insuree account address");
        require(msg.sender == insurance, "insuree calls this function");
        require(amount == msg.value,"amount must equal value sent");

        bytes32 key = getFlightKey(airline, flight, timeStamp);
        airline.transfer(amount);
        insurances[insurance].insuranceAmount += amount;
        insuranceBalance += amount;

        emit BoughtInsurance(msg.sender, key, amount);

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            requireIsOperational
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (  
                            address airline 
                            )
                            public
                            payable
                             requireIsOperational
    {
        require(msg.value >= 10 ether, "Inadaquate funds");
        require(airlines[airline].isRegistered, "Sending account must be registered before it can be funded");


        uint256 totalAmount = totalAmount.add(msg.value);
        airline.transfer(msg.value); //their code has the totalAmount being transferred to the contract account. Why?

        if (!airlines[airline].isAuthorized) {
            airlines[airline].isAuthorized = true;
            authorizedAirlineCount = authorizedAirlineCount.add(1);
            emit AuthorizedAirline(airline);
        }
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund(msg.sender);
    }


}

