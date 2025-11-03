//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionsTest is Test, CodeConstants {
    HelperConfig helperConfig;
    CreateSubscription createSubscription;
    AddConsumer addConsumer;
    FundSubscription fundSubscription;

    function setUp() public {
        helperConfig = new HelperConfig();
        helperConfig.getConfigByChain(block.chainid); // Initialize localNetworkConfig
        createSubscription = new CreateSubscription(helperConfig);
        addConsumer = new AddConsumer(helperConfig);
        fundSubscription = new FundSubscription(helperConfig);
    }

    function testCreateSubscriptionUsingConfigFetchesCorrectParams() public {
        (uint256 subscriptionId, address vrfCoordinator) = createSubscription
            .createSubscriptionUsingConfig();

        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChain(block.chainid);

        assertEq(
            vrfCoordinator,
            config.vrfCoordinator,
            "VRF Coordinator mismatch"
        );
        assertGt(subscriptionId, 0, "Subscription ID should be greater than 0");
    }

    function testCreateSubscriptionRevertsWithInvalidCoordinator() public {
        // Arrange
        address invalidVrfCoordinator = address(0);
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChain(block.chainid);

        // Act & Assert
        vm.expectRevert();
        createSubscription.createSubscription(
            invalidVrfCoordinator,
            config.account
        );
    }

    function testAddConsumerUsingConfig() public {
        (uint256 subscriptionId, address vrfCoordinator) = createSubscription
            .createSubscriptionUsingConfig();

        address owner = helperConfig.getConfigByChain(block.chainid).account;
        address consumer = address(this);
        addConsumer.addConsumer(
            consumer,
            vrfCoordinator,
            subscriptionId,
            owner
        );
    }

    function testAddConsumerRevertsWhenExceedingMaxConsumers() public {
        // Step 1: Create a subscription
        (uint256 subscriptionId, address vrfCoordinator) = createSubscription
            .createSubscriptionUsingConfig();

        address owner = helperConfig.getConfigByChain(block.chainid).account;

        // Step 2: Add consumers up to the MAX_CONSUMERS limit
        for (uint256 i = 0; i < 100; i++) {
            address consumer = address(uint160(i + 1)); // Generate unique consumer addresses
            addConsumer.addConsumer(
                consumer,
                vrfCoordinator,
                subscriptionId,
                owner
            );
        }

        // Step 3: Attempt to add one more consumer and expect a revert
        address extraConsumer = address(0xDEADBEEF); // An additional consumer
        vm.expectRevert(abi.encodeWithSignature("TooManyConsumers()"));
        addConsumer.addConsumer(
            extraConsumer,
            vrfCoordinator,
            subscriptionId,
            owner
        );
    }

    function testFundSubscriptionRevertsIfSubscriptionIdIs0() public {
        vm.expectRevert();
        fundSubscription.fundSubcriptionUsingConfig();
    }

    function testFundScriptionUsingConfigFundsCorrectly() public {
        (uint256 subscriptionId, address vrfCoordinator) = createSubscription
            .createSubscriptionUsingConfig();

        address owner = helperConfig.getConfigByChain(block.chainid).account;
        address consumer = address(this);
        addConsumer.addConsumer(
            consumer,
            vrfCoordinator,
            subscriptionId,
            owner
        );

        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChain(block.chainid);

        fundSubscription.fundSubscription(
            vrfCoordinator,
            subscriptionId,
            config.link,
            owner
        );

        uint256 expectedAmountFunded = (block.chainid == LOCAL_CHAIN_ID)
            ? fundSubscription.FUND_AMOUNT() * 100
            : fundSubscription.FUND_AMOUNT();

        (uint96 balance, , , , ) = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .getSubscription(subscriptionId);

        assertEq(
            balance,
            expectedAmountFunded,
            "Subscription balance does not match the funded amount"
        );
    }
}
