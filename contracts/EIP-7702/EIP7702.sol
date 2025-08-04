// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract UX7702Delegator  {
	event Executed(address caller, address sender, address target, uint256 value, bytes data);
	struct VerifyParams {bytes signature; address[] targets; uint256[] values; bytes[] datas; uint256 random;}

	function uxExecuteBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas, bytes calldata signature) external payable {
		address ux7702Validator = 0x469555D052Ad53CA0C032cDb22C32964476D0355;
		require(targets.length == datas.length && targets.length == values.length, "Wrong lengths");
		uint256 random = _getRandom(address(this));
		VerifyParams memory params = VerifyParams({
			signature: signature,
			targets: targets,
			values: values,
			datas: datas,
			random: random
		});
		_verifySign(ux7702Validator, params);
		for (uint256 i = 0; i < targets.length; i++) {
			_call(targets[i], values[i], datas[i]);
			emit Executed(address(this), msg.sender, targets[i], values[i], datas[i]);
		}
		_checkSign(ux7702Validator, signature, random);
	}

	function _getRandom(address caller) internal view returns (uint256) {
		return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.prevrandao, caller, tx.origin)));
	}

	function _call(address target, uint256 value, bytes memory data) internal {
		(bool success, bytes memory result) = target.call{value: value}(data);
		if (!success) {
			assembly {
				revert(add(result, 32), mload(result))
			}
		}
	}

	function _verifySign(address ux7702Validator, VerifyParams memory params) internal {
		(bool success, bytes memory result) = ux7702Validator.call(
			abi.encodeWithSignature(
				"verifySign(bytes,address[],uint256[],bytes[],uint256)",
				params.signature, params.targets, params.values, params.datas, params.random
			)
    );
		if (!success) {
			assembly {
				revert(add(result, 32), mload(result))
			}
		}
	}

	function _checkSign(address ux7702Validator, bytes calldata signature, uint256 random) internal {
		(bool success, ) = ux7702Validator.call(abi.encodeWithSignature(
			"checkSign(bytes,uint256)",
			signature, random
		));
		require(success, "Check failed");
	}
}

