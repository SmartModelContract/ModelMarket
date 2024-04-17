// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StringStorage {
    // Array to store strings
    string[] public strings;

    // Event declaration for logging string submission
    event StringSubmitted(string submittedString, uint256 index);

    // Function to submit a string. Any address can call this function.
    function submitString(string memory newString) public {
        strings.push(newString); // Add the new string to the array
        emit StringSubmitted(newString, strings.length - 1); // Emit an event with the submitted string and its index
    }

    // Function to retrieve a string by index
    function getString(uint256 index) public view returns (string memory) {
        require(index < strings.length, "Index out of bounds"); // Check that the index is valid
        return strings[index]; // Return the string at the specified index
    }

    // Function to get the total number of strings stored
    function getTotalStrings() public view returns (uint256) {
        return strings.length; // Return the length of the strings array
    }

    // Function to retrieve a the last string if it exists
    function getLastString() public view returns (string memory) {
        require(strings.length > 0, "No strings submitted yet");
        return strings[strings.length - 1]; // Check that the index is valid
    }

}

