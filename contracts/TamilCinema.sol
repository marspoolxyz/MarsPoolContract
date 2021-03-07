pragma solidity ^0.7.0;

import "./ERC165/IERC165.sol";
import "./ERC165/ERC165.sol";
import "./utils/Address.sol";
import "./utils/EnumerableMap.sol";
import "./utils/EnumerableSet.sol";
import "./utils/SafeMath.sol";
import "./utils/Strings.sol";
import "./utils/Context.sol";
import "./utils/Ownable.sol";
import "./IERC20.sol";
import "./IMasks.sol";
import "./IERC721Enumerable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);
}

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

/**
 * @title Hashmasks contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract TamilCinema is Context, Ownable, ERC165, IMasks, IERC721Metadata {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for string;

    // Public variables

    // This is the provenance record of all Hashmasks artwork in existence
    string public constant HASHMASKS_PROVENANCE = "df760c771ad006eace0d705383b74158967e78c6e980b35f670249b5822c42e1";

    uint256 public constant SALE_START_TIMESTAMP = 1614954923;

    // Time after which hash masks are randomized and allotted
    uint256 public constant REVEAL_TIMESTAMP = SALE_START_TIMESTAMP + (86400 * 14);

    uint256 public constant NAME_CHANGE_PRICE = 1830 * (10 ** 18);

    uint256 public constant MAX_NFT_SUPPLY = 1786;
	
    uint256 public constant MAX_PUBLIC_NFT = 1782;	

    uint256 public startingIndexBlock;

    uint256 public startingIndex;
    
    uint256 private SALE_BALANCE = 0;
    

    
    // Mapping from token ID to tenant
    mapping (uint256 => address) private _tenant;    
    
    // Mapping from token ID to tenantDeposit
    mapping (uint256 => uint256) private _tenantDeposit;   
    
    // Mapping from token ID to rentalAmount
    mapping (uint256 => uint256) private _rentalAmount;   
    
    // Mapping from token ID to rental status
    mapping (uint256 => bool) private _isOnRent;   
    

   // Mapping from token ID to rental start    
    mapping (uint256 => uint256) private _agreementExpiry; 
    
   // Mapping from token ID to rental start    
    mapping (uint256 => uint256) private _rent_start;   
    
   // Mapping from token ID to rental end
    mapping (uint256 => uint256) private _rent_end;   

    // Mapping from token ID to approved tenant
    mapping (uint256 => address) private _approvedTenant;  

    // Mapping from token ID to agreement tenant
    mapping (uint256 => address) private _agreementTenant;  
    

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Enumerable mapping from token ids to the 1st owners
    EnumerableMap.UintToAddressMap private _initialOwners;


    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from token ID to name
    mapping (uint256 => string) private _tokenName;

    // Mapping if certain name string has already been reserved
    mapping (string => bool) private _nameReserved;

    // Mapping from token ID to whether the Hashmask was minted before reveal
    mapping (uint256 => bool) private _mintedBeforeReveal;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Name change token address
    address private _nctAddress;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *
     *     => 0x06fdde03 ^ 0x95d89b41 == 0x93254542
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x93254542;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    // Events
    event NameChange (uint256 indexed maskIndex, string newName);

    // Events
    event RentalApproved (uint256 indexed maskIndex, address tenant);

    // Agreement Created for the tenant
    event AgreementReady (uint256 indexed maskIndex, address tenant);

    // Agreement already exist for the NFT
    event AgreementExist (uint256 indexed maskIndex);
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name, string memory symbol, address nctAddress) {
        _name = name;
        _symbol = symbol;
        _nctAddress = nctAddress;

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);

    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");

        return _holderTokens[owner].length();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
    }


    /**
     * @dev Returns address of the First owner of NFT at index.
     */
    function initialOwnerOf(uint256 tokenId) public view override returns (address initialOwner) {
        return _initialOwners.get(tokenId, "ERC721: owner query for nonexistent token");
    }


    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    /**
     * @dev Returns name of the NFT at index.
     */
    function tokenNameByIndex(uint256 index) public view returns (string memory) {
        return _tokenName[index];
    }

    /**
     * @dev Returns if the name has been reserved.
     */
    function isNameReserved(string memory nameString) public view returns (bool) {
        return _nameReserved[toLower(nameString)];
    }

    /**
     * @dev Returns if the NFT has been minted before reveal phase
     */
    function isMintedBeforeReveal(uint256 index) public view override returns (bool) {
        return _mintedBeforeReveal[index];
    }

    /**
     * @dev Gets current Hashmask Price
     */
    function getNFTPrice() public view returns (uint256) {
        require(block.timestamp >= SALE_START_TIMESTAMP, "Sale has not started");
        require(totalSupply() < MAX_PUBLIC_NFT, "Sale has already ended");

        uint currentSupply = totalSupply();
		// 1783 , 1784, 1785 Team Reserve
        if (currentSupply >= 1780) {
            return 10000000000000000000; 	// 1780 - 1782 	10 ETH
        } else if (currentSupply >= 1530) {
            return 2600000000000000000; 	// 1530 - 1779 		2.6 ETH
        } else if (currentSupply >= 1180) {
            return 1400000000000000000; 	// 1180  - 1529 	1.4 ETH
        } else if (currentSupply >= 790) {
            return 900000000000000000; 		// 790 - 1179 		0.9 ETH
        } else if (currentSupply >= 450) {
            return 500000000000000000; 		// 450 - 789 		0.5 ETH
        } else if (currentSupply >= 200) {
            return 300000000000000000; 		// 200 - 449 		0.3 ETH
        } else {
            return 100000000000000000; 		// 0 - 199 			0.1 ETH 
        }
    }

    /**
    * @dev Mints Masks
    */
    function mintNFT(uint256 numberOfNfts) public payable {
        require(totalSupply() < MAX_PUBLIC_NFT, "Sale has already ended");
        require(numberOfNfts > 0, "You may need to buy atleast 1 NFT");
        require(numberOfNfts <= 5, "You may not buy more than 5 NFTs at once");
        require(totalSupply().add(numberOfNfts) <= MAX_PUBLIC_NFT, "Exceeds MAX_PUBLIC_NFT");
        require(getNFTPrice().mul(numberOfNfts) == msg.value, "Ether value sent is not correct");

        for (uint i = 0; i < numberOfNfts; i++) {
            uint mintIndex = totalSupply();
            if (block.timestamp < REVEAL_TIMESTAMP) {
                _mintedBeforeReveal[mintIndex] = true;
            }
            _safeMint(msg.sender, mintIndex);
        }
        
        SALE_BALANCE = SALE_BALANCE + msg.value;

        /**
        * Source of randomness. Theoretical miner withhold manipulation possible but should be sufficient in a pragmatic sense
        */
        if (startingIndexBlock == 0 && (totalSupply() == MAX_NFT_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    }


    /**
    * @dev Rental Deposit   _tokenName[tokenId] = newName;

    */
    function rentDeposit(uint256 tokenId) public payable {
        
         require(_isOnRent[tokenId] != true," NFT is not available for Rent !" );
         // Only one deposit at a time
         require(_tenantDeposit[tokenId] == 0," Already a tenant is waiting for rental approval !" );
         require(msg.value > 0," Deposit cannot be zero !" );
         
         _tenant[tokenId] = msg.sender;        // Potential Tenenant
         _tenantDeposit[tokenId] = msg.value;  // Amount sent as Deposit
    }
    
    /**
    * @dev Withdraw anytime before rental agreement approved
    */
    function withdrawDeposit(uint256 tokenId) public {
        
        require(msg.sender == _tenant[tokenId]," You don't have any rental deposits !" );
        require(_isOnRent[tokenId] == false," Your rental agreement is in progress !" );
        

        // If rental agreement is still not started then transfer the deposit        
        msg.sender.transfer(_tenantDeposit[tokenId]);
        
        _tenantDeposit[tokenId] = 0; // Reset amount to zero
        _tenant[tokenId] = address(0);        
    }  
    


    
    /**
     * @dev Returns amount deposited by potential tenant at index.
     */
    function depositByIndex(uint256 index) public view returns (address,uint256) {
        return (_tenant[index],_tenantDeposit[index]);
    }
    

    /**
     * @dev Returns Agreement between owner and tenant for approval
     *  _rent_start[tokenId] = start_time;
        _rent_end[tokenId] = end_time;
     */ 
    function getAgreement(uint256 index) public view returns (address, uint256, uint256,uint256) {
        
        // True if expired & false if still valid
        uint256 isExpired = ((_agreementExpiry[index] < block.timestamp)) ? 1:0;

        return (_agreementTenant[index], _rent_start[index], _rent_end[index], isExpired);
    }        
    
    /**
     * @dev Returns name of the NFT at index.
     *     function tenantOf(uint256 index) public view override returns (address tenantAddress) 
     */
    function tenantOf(uint256 index) public view override returns (address tenantAddress)  {

        if(block.timestamp > _rent_end[index] || _isOnRent[index] == false)
        {
            return address(0);
        }
        return _approvedTenant[index];
    }
    
    /**
    * @dev Approve the agreement between the Owner and Tenant
    */
    function ApproveAgreement(uint256 tokenId) public {
        
        require(msg.sender == _tenant[tokenId]," You don't have any rental deposits for the Token !" );
        require(msg.sender == _agreementTenant[tokenId]," Request NFT owner for rental agreement !" );
        require(_isOnRent[tokenId] != true," Your rental agreement is in progress !" );
        require(_agreementExpiry[tokenId] > block.timestamp, "Agreement already expired !");

        _tenant[tokenId] = address(0);           //Set by Tenant
        _agreementTenant[tokenId] = address(0);  // Agreement Tenant set by owner
        _approvedTenant[tokenId] = msg.sender;  // Now,tenant  will start getting the revenue
        _isOnRent[tokenId] = true;

    }  
        
    
    /**
     * @dev Set the rental period and tenant for the NFT tokenId
     */
    function rentalAgreement(uint256 tokenId, uint256 start_time , uint256 end_time, address agreementTenant) public {
        address owner = ownerOf(tokenId);
        
        require(msg.sender == owner, "ERC721: caller is not the owner");
        require(block.timestamp < start_time, "Rental start time should be in future !");
        require(block.timestamp < end_time, "Rental end time should be in future !");
        require(start_time < end_time, "StartTime cannot be more than EndTime !");

        //require(owner != agreementTenant, "You cannot rent yourself !");        
        
        if(_approvedTenant[tokenId] != address(0)) // Claim Rent
        {
             //Claim any pending rental 
            if(_tenantDeposit[tokenId] > 0)
            {
                msg.sender.transfer(_tenantDeposit[tokenId]);
                _tenantDeposit[tokenId] = 0; // Reset amount to zero
            }
        }

        // Check is there is any expired tenancy 
        if(block.timestamp > _rent_end[tokenId])
        {
            _approvedTenant[tokenId] = address(0);  // Remove the tenant
            _isOnRent[tokenId] = false;
            _agreementTenant[tokenId] = address(0);  
        }   
       
       //require(_agreementExpiry[tokenId] < block.timestamp, "There is an agreement already, wait for expiry !");
       
       if(_agreementExpiry[tokenId] > block.timestamp)
       {
        _approvedTenant[tokenId] = address(0);
        _rent_start[tokenId] = start_time;
        _rent_end[tokenId] = end_time;
        _agreementExpiry[tokenId] = block.timestamp + (15 * 60); // 15 minutes from now
        _agreementTenant[tokenId] = agreementTenant;
        emit AgreementReady(tokenId, agreementTenant);
       } 
       else
       {
        emit AgreementExist(tokenId);
       }

        
    }    
    

    /**
     * @dev Finalize starting index
     */
    function finalizeStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");
        
        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_NFT_SUPPLY;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number-1)) % MAX_NFT_SUPPLY;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    /**
     * @dev Changes the name for Hashmask tokenId
     */
    function changeName(uint256 tokenId, string memory newName) public {
        address owner = ownerOf(tokenId);

        require(_msgSender() == owner, "ERC721: caller is not the owner");
        require(validateName(newName) == true, "Not a valid new name");
        require(sha256(bytes(newName)) != sha256(bytes(_tokenName[tokenId])), "New name is same as the current one");
        require(isNameReserved(newName) == false, "Name already reserved");

        IERC20(_nctAddress).transferFrom(msg.sender, address(this), NAME_CHANGE_PRICE);
        // If already named, dereserve old name
        if (bytes(_tokenName[tokenId]).length > 0) {
            toggleReserveName(_tokenName[tokenId], false);
        }
        toggleReserveName(newName, true);
        _tokenName[tokenId] = newName;
        IERC20(_nctAddress).burn(NAME_CHANGE_PRICE);
        emit NameChange(tokenId, newName);
    }

    /**
     * @dev Withdraw ether from this contract (Callable by owner)
    */
    function withdraw() onlyOwner public {
        
        // uint balance = address(this).balance;
        
        msg.sender.transfer(SALE_BALANCE);
        
        SALE_BALANCE = 0;
    }
    
    /**
     * @dev Withdraw last 3 NFTs from the contract (Callable by owner) 1783 , 1784 , 1785
    */
    function withdrawTeamNFTs() onlyOwner public {
        require(totalSupply() > MAX_PUBLIC_NFT, "Team Tokens claimed !");

        for (uint i = 0; i < 3; i++) {
            uint mintIndex = totalSupply();
            if (block.timestamp < REVEAL_TIMESTAMP) {
                _mintedBeforeReveal[mintIndex] = true;
            }
            _safeMint(msg.sender, mintIndex);
        }

        /**
        * Source of randomness. Theoretical miner withhold manipulation possible but should be sufficient in a pragmatic sense
        */
        if (startingIndexBlock == 0 && (totalSupply() == MAX_NFT_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }		
		
		withdraw();
    }


    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _tokenOwners.contains(tokenId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     d*
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);
        
        _initialOwners.set(tokenId,to);

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _holderTokens[owner].remove(tokenId);

        _tokenOwners.remove(tokenId);
        
        _initialOwners.remove(tokenId);

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }


    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
            IERC721Receiver(to).onERC721Received.selector,
            _msgSender(),
            from,
            tokenId,
            _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    function _approve(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }

    /**
     * @dev Reserves the name if isReserve is set to true, de-reserves if set to false
     */
    function toggleReserveName(string memory str, bool isReserve) internal {
        _nameReserved[toLower(str)] = isReserve;
    }

    /**
     * @dev Converts the string to lowercase
     */
    function toLower(string memory str) public pure returns (string memory){
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
    
    /**
     * @dev Check if the name string is valid (Alphanumeric and spaces without leading or trailing space)
     */
    function validateName(string memory str) public pure returns (bool){
        bytes memory b = bytes(str);
        if(b.length < 1) return false;
        if(b.length > 25) return false; // Cannot be longer than 25 characters
        if(b[0] == 0x20) return false; // Leading space
        if (b[b.length - 1] == 0x20) return false; // Trailing space

        bytes1 lastChar = b[0];

        for(uint i; i<b.length; i++){
            bytes1 char = b[i];

            if (char == 0x20 && lastChar == 0x20) return false; // Cannot contain continous spaces

            if(
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x20) //space
            )
                return false;

            lastChar = char;
        }

        return true;
    }   



}