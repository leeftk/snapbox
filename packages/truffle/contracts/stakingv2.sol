pragma solidity 0.8.17;

import "./SwapExample.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract snapETH is IERC20 {
    constructor() public IERC20("snapETH", "SNAP") {
    }
     function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
     function burn(address _to, uint256 _amount) public onlyOwner {
        _burn(_to, _amount);
    }
}

contract Staking is SwapExamples, snapETH {

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;

    // Duration of rewards to be paid out (in seconds)
    uint public duration;
    // Timestamp of when the rewards finish
    uint public finishAt;
    // Minimum of last updated time and reward finish time
    uint public updatedAt;
    // Reward to be paid out per second
    uint public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // address where fees will be distributed
    address public feeDistributor;
    //total amount of STETH in contract
    uint256 public balanceNow = IERC20(STETH).balanceOf(address(this));
    // If this app charges fess should be true;
    bool chargeFees = true;

    
    // User address => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;

    bool public chargefees;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    mapping(address => uint) public balacneSnapshot;

       constructor(
        address _stakingToken,
        address _feeDistributor
    ) {

        owner = msg.sender;
        feeDistributor = _feeDistributor;
        stakingToken = IERC20(_stakingToken);
    }

    function deposit(uint _amount) public {
        require(_amount > 0, "amount = 0");
        //update user balance
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
        //swaps eth for steth on uniswap and sends to this contract
        swapExactInputSingle(_amount, address(this)); 
        //mint receipt token snapETH which represents 1:1 stETH
        _mint(_amount,msg.sender);
    }

    function getBalance(address _address) public view returns(uint) {
        return balanceOf[_address];
    }

    function getRewardBalance(address _address) public view returns(uint) {
        return balanceNow.mul(balanceOf[_address]).div(totalSupply);
    }

    
    function withdraw(uint256 _amount, uint _pid) public {
        require(_amount > 0, "amount = 0");
        require(balanceOf[msg.sender] >= _amount);
        _chargeFees();
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        //swaps stETH for WETH
        swapExactInputSingle(_amount, msg.sender);
        _burn(_amount,msg.sender);
        
    }
    //charges normal 2 and 20 hedge fund fees
        function _chargeFees() internal virtual {
        if (chargeFees) {
            uint256 snapshotAssetBalance = balanceOf[msg.sender];
            uint256 userShare = balanceNow.mul(snapshotAssetBalance).div(totalSupply);
            //  100 * 1 /10
            // balancenow * (balanceDeposited /total Supply) *
            if (userShare > snapshotAssetBalance) {
                // send performance fee to fee distributor (20% on profit wrt benchmark)
                // 1 / 5 = 20 / 100
                IERC20(STETH).safeTransfer(
                    feeDistributor,
                    (userShare - snapshotAssetBalance) / 5
                ); 
            }
            // send management fee to fee distributor (2% annually)
            // 1 / 600 = 2 / (100 * 12)
            IERC20(STETH).safeTransfer(
                feeDistributor,
                snapshotAssetBalance / 600
            );
        }
    }
}
