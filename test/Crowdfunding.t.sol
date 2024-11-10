// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CrowdfundingPlatform.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// Mock Contract for ProjectToken
contract MockProjectToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract CrowdfundingPlatformTest is Test {
    // Declare contracts
    CrowdfundingPlatform public crowdfundingPlatform;
    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;

    address public admin;
    address public user1;
    address public user2;

    uint256 public initialSupply = 1000 * 10 ** 18; // 1000 tokens with 18 decimals

    // Initialize some basic values
    function setUp() public {
        // Set up admin and user addresses
        admin = address(1);
        user1 = address(2);
        user2 = address(3);

        // Deploy Uniswap mock router and factory
        uniswapRouter = IUniswapV2Router02(address(0)); // You can use actual deployed addresses on testnet
        uniswapFactory = IUniswapV2Factory(address(0)); // Same here, use testnet or local mock

        // Deploy Crowdfunding Platform contract
        crowdfundingPlatform = new CrowdfundingPlatform(address(uniswapRouter), address(uniswapFactory));
    }

    // Test project creation
    function testCreateProject() public {
        string memory projectName = "Test Project";
        string memory tokenSymbol = "TSP";
        uint256 ethForLiquidity = 1 ether;
        string memory imageURL = "https://example.com/project-image.jpg";

        // Admin creates a project with 1 ETH for liquidity
        vm.startPrank(admin);
        crowdfundingPlatform.createProject(projectName, tokenSymbol, initialSupply, ethForLiquidity, imageURL);
        vm.stopPrank();

        // Verify the project is created
        CrowdfundingPlatform.Project[] memory projects = crowdfundingPlatform.projects();
        assertEq(projects.length, 1, "Project was not created");
        assertEq(projects[0].name, projectName, "Incorrect project name");
        assertEq(projects[0].tokenAddress != address(0), true, "Incorrect token address");
    }

    // Test contributions to a project
    function testContributeToProject() public {
        string memory projectName = "Test Project";
        string memory tokenSymbol = "TSP";
        uint256 ethForLiquidity = 1 ether;
        string memory imageURL = "https://example.com/project-image.jpg";

        // Admin creates a project
        vm.startPrank(admin);
        crowdfundingPlatform.createProject(projectName, tokenSymbol, initialSupply, ethForLiquidity, imageURL);
        vm.stopPrank();

        // User contributes to the project
        uint256 contributionAmount = 0.5 ether;
        vm.startPrank(user1);
        crowdfundingPlatform.contribute{value: contributionAmount}(0); // Contribute to the first project
        vm.stopPrank();

        // Verify contribution and reward distribution
        CrowdfundingPlatform.Project[] memory projects = crowdfundingPlatform.projects();
        assertEq(projects[0].ethRaised, contributionAmount, "Incorrect ETH raised for project");

        // Verify that user1 received tokens as a reward
        ERC20 token = ERC20(projects[0].tokenAddress);
        uint256 userBalance = token.balanceOf(user1);
        assertTrue(userBalance > 0, "User should have received tokens as a reward");
    }

    // Test liquidity retrieval for a project
    function testGetLiquidity() public {
        string memory projectName = "Test Project";
        string memory tokenSymbol = "TSP";
        uint256 ethForLiquidity = 1 ether;
        string memory imageURL = "https://example.com/project-image.jpg";

        // Admin creates a project
        vm.startPrank(admin);
        crowdfundingPlatform.createProject(projectName, tokenSymbol, initialSupply, ethForLiquidity, imageURL);
        vm.stopPrank();

        // Retrieve liquidity for the project
        (uint256 reserveToken, uint256 reserveETH) = crowdfundingPlatform.getLiquidity(0);

        assertEq(reserveToken > 0, true, "Token reserve should be greater than 0");
        assertEq(reserveETH > 0, true, "ETH reserve should be greater than 0");
    }

    // Test token swap functionality
    function testSwapTokensForETH() public {
        string memory projectName = "Test Project";
        string memory tokenSymbol = "TSP";
        uint256 ethForLiquidity = 1 ether;
        string memory imageURL = "https://example.com/project-image.jpg";

        // Admin creates a project
        vm.startPrank(admin);
        crowdfundingPlatform.createProject(projectName, tokenSymbol, initialSupply, ethForLiquidity, imageURL);
        vm.stopPrank();

        // User 1 contributes to the project
        uint256 contributionAmount = 0.5 ether;
        vm.startPrank(user1);
        crowdfundingPlatform.contribute{value: contributionAmount}(0);
        vm.stopPrank();

        // User 1 swaps tokens for ETH
        CrowdfundingPlatform.Project[] memory projects = crowdfundingPlatform.projects();
        address tokenAddress = projects[0].tokenAddress;
        uint256 tokenAmount = ERC20(tokenAddress).balanceOf(user1);

        vm.startPrank(user1);
        crowdfundingPlatform.swapTokensForETH(tokenAddress, tokenAmount, 1); // Swapping tokens for ETH with a min output of 1 ETH
        vm.stopPrank();

        // Ensure the user has received ETH
        uint256 userEthBalance = user1.balance;
        assertTrue(userEthBalance > 0, "User should have received ETH after token swap");
    }
}
