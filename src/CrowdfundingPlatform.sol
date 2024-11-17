// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./ProjectToken.sol";

contract CrowdfundingPlatform {
    struct Project {
        string title;
        string description;
        address tokenAddress;
        address liquidityPool;
        uint256 ethRaised;
        address creator;
        uint256 totalSupply;
        string imageURL;
    }

    Project[] public projects;
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapFactory;

    constructor(address _router, address _factory) {
        uniswapRouter = IUniswapV2Router02(_router);
        uniswapFactory = _factory;
    }

    event ProjectCreated(string name, address tokenAddress, address liquidityPool, address creator);
    event FundsWithdrawn(uint256 projectIndex, address creator, uint256 amount);

    function createProject(
        string memory _title,
        string memory _description,
        string memory _tokenName,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 ethForLiquidity,
        string memory _imageURL
    ) public payable {
        require(msg.value >= ethForLiquidity, "Not enough ETH for liquidity");

        ProjectToken newToken = new ProjectToken(_tokenName, _symbol, _initialSupply);

        uint256 tokenLiquidityAmount = (_initialSupply * 50) / 100 * 10 ** newToken.decimals();

        newToken.approve(address(uniswapRouter), tokenLiquidityAmount);

        uniswapRouter.addLiquidityETH{value: ethForLiquidity}(
            address(newToken), tokenLiquidityAmount, 0, 0, address(this), block.timestamp + 100
        );

        address liquidityPool = IUniswapV2Factory(uniswapFactory).getPair(address(newToken), uniswapRouter.WETH());

        projects.push(
            Project({
                title: _title,
                description: _description,
                tokenAddress: address(newToken),
                liquidityPool: liquidityPool,
                ethRaised: 0,
                creator: msg.sender,
                totalSupply: _initialSupply * 10 ** newToken.decimals(),
                imageURL: _imageURL
            })
        );

        emit ProjectCreated(_title, address(newToken), liquidityPool, msg.sender);
    }

    function contribute(uint256 projectIndex) public payable {
        Project storage project = projects[projectIndex];
        require(msg.value > 0, "Must contribute ETH");

        project.ethRaised += msg.value;

        uint256 rewardAmount = calculateReward(msg.value, project.totalSupply);
        ERC20(project.tokenAddress).transfer(msg.sender, rewardAmount);
    }

    function calculateReward(uint256 ethAmount, uint256 totalSupply) internal pure returns (uint256) {
        return (ethAmount * totalSupply) / 1 ether;
    }

    function getLiquidity(uint256 projectIndex) public view returns (uint256 reserveToken, uint256 reserveETH) {
        Project storage project = projects[projectIndex];
        require(project.liquidityPool != address(0), "Liquidity pool does not exist for this project");

        IUniswapV2Pair pair = IUniswapV2Pair(project.liquidityPool);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

        address token0 = pair.token0();
        if (token0 == project.tokenAddress) {
            return (reserve0, reserve1);
        } else {
            return (reserve1, reserve0);
        }
    }

    function swapTokensForETH(address tokenAddress, uint256 tokenAmount, uint256 minEthOut) public returns (bool) {
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), tokenAmount);

        require(token.balanceOf(address(this)) >= tokenAmount, "Not enough tokens");

        require(token.approve(address(uniswapRouter), tokenAmount), "Token approval failed");

        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = uniswapRouter.WETH();

        uniswapRouter.swapExactTokensForETH(tokenAmount, minEthOut, path, msg.sender, block.timestamp + 600);

        return true;
    }

    function withdrawFunds(uint256 projectIndex) public {
        Project storage project = projects[projectIndex];
        require(msg.sender == project.creator, "Only the project creator can withdraw funds");
        require(project.ethRaised > 0, "No funds to withdraw");

        uint256 amountToWithdraw = project.ethRaised;
        project.ethRaised = 0;

        (bool success,) = msg.sender.call{value: amountToWithdraw}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(projectIndex, msg.sender, amountToWithdraw);
    }

    function getProjectCount() public view returns (uint256) {
        return projects.length;
    }
}
