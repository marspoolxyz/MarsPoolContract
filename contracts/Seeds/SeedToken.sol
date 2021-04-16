// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../ERC165/IERC165.sol";
import "../utils/SafeMath.sol";
import "../IERC20.sol";
import "../ISeeds.sol";
import "../utils/Context.sol";

/**
 *
 * Seeds Contract (Seeds can be harvested only by owning NFT)
 * @dev Extends standard ERC20 contract
 */
contract SeedToken  is Context, IERC20 {
    using SafeMath for uint256;

    // Constants
    uint256 public SECONDS_IN_A_DAY = 86400;

    uint256 public constant INITIAL_ALLOTMENT = 500 * (10 ** 18);

    uint256 public constant PRE_REVEAL_MULTIPLIER = 2;

    // Public variables
    uint256 public harvestStart;

    uint256 public harvestEnd; 

    uint256 public seedsPerDay = 10 * (10 ** 18);

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;
    
    mapping(uint256 => uint256) private _lastharvest;

    //  Royalty Parameters
    // mapping(uint256 => address) private _initialOwners;
    // mapping (address => uint256) private _royaltyValue;
    
    uint256 public PERCENTAGE_OF_ROYALTY = 20;
    

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _MarsPoolLandAddress;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18. Also initalizes {harvestStart}
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory token_name, string memory token_symbol, uint256 harvestStartTimestamp) {
        _name = token_name;
        _symbol = token_symbol;
        _decimals = 18;
        harvestStart = harvestStartTimestamp;
        harvestEnd = harvestStartTimestamp + (86400 * 365 * 5);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev When matured SEEDs have last been harvested for a MarsPool Land index
     */
    function lastharvest(uint256 tokenIndex) public view returns (uint256) {
        require(ISeeds(_MarsPoolLandAddress).ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");
        require(tokenIndex < ISeeds(_MarsPoolLandAddress).totalSupply(), "MarsPool Land at index has not been minted yet");

        uint256 lastHarvest = uint256(_lastharvest[tokenIndex]) != 0 ? uint256(_lastharvest[tokenIndex]) : harvestStart;
        return lastHarvest;
    }
    
    /**
     * @dev Ready to harvest SEED tokens for a MarsPool Land token index.
     */
    function accumulated(uint256 tokenIndex) public view returns (uint256) {
        require(block.timestamp > harvestStart, "Harvest has not started yet");
        require(ISeeds(_MarsPoolLandAddress).ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");
        require(tokenIndex < ISeeds(_MarsPoolLandAddress).totalSupply(), "MarsPool Land at index has not been minted yet");

        uint256 lastHarvest = lastharvest(tokenIndex);

        // When was the last harvest
        if (lastHarvest >= harvestEnd) return 0;

        uint256 accumulationPeriod = block.timestamp < harvestEnd ? block.timestamp : harvestEnd; // Getting the min value of both
        uint256 totalAccumulated = accumulationPeriod.sub(lastHarvest).mul(seedsPerDay).div(SECONDS_IN_A_DAY);

        // If harvest hasn't been done before for the Land(index), add initial allotment (plus prereveal multiplier if applicable)
        if (lastHarvest == harvestStart) {
            uint256 initialAllotment = ISeeds(_MarsPoolLandAddress).isMintedBeforeReveal(tokenIndex) == true ? INITIAL_ALLOTMENT.mul(PRE_REVEAL_MULTIPLIER) : INITIAL_ALLOTMENT;
            totalAccumulated = totalAccumulated.add(initialAllotment);
        }

        return totalAccumulated;
    }

    /**
     * @dev Permissioning not added because it is only callable once.
     * It is set right after deployment and verified.
     */
    function setLandAddress(address MarsPoolLandAddress) public {
        require(_MarsPoolLandAddress == address(0), "Already set");
        
        _MarsPoolLandAddress = MarsPoolLandAddress;
    }
    
    /**
     * @dev Harvest SEEDs from more than one MarsPool Land indices at once
     */
    function harvest(uint256[] memory tokenIndices) public returns (uint256) {
        require(block.timestamp > harvestStart, "Emission has not started yet");

        uint256 totalharvestQty = 0;
        address owner = ISeeds(_MarsPoolLandAddress).ownerOf(tokenIndices[0]); 

        for (uint i = 0; i < tokenIndices.length; i++) {
            // Sanity check for non-minted index
            require(tokenIndices[i] < ISeeds(_MarsPoolLandAddress).totalSupply(), "LAND at index has not been minted yet");
            // Duplicate token index check
            for (uint j = i + 1; j < tokenIndices.length; j++) {
                require(tokenIndices[i] != tokenIndices[j], "Duplicate token index");
            }

            uint tokenIndex = tokenIndices[i];
            address currentTenant = ISeeds(_MarsPoolLandAddress).tenantOf(tokenIndex); // Is NFT rented ?
 
            // LAND Owner or Tenant can only harvest the SEEDs 
            if(currentTenant == address(0))
            {
                require(ISeeds(_MarsPoolLandAddress).ownerOf(tokenIndex) == msg.sender, "Sender is not the owner");
            }
            else
            {
                
                require(ISeeds(_MarsPoolLandAddress).tenantOf(tokenIndex) == currentTenant, "Sender is not the owner");
            }
            /***************************************************/
            
            uint256 harvestQty = accumulated(tokenIndex);            
            
            address initialOwner = ISeeds(_MarsPoolLandAddress).initialOwnerOf(tokenIndex);
            
            if(initialOwner != address(0) && ISeeds(_MarsPoolLandAddress).ownerOf(tokenIndex) != initialOwner)
            {
                // The current token was sold in secondary market, we know the initial owner

                 uint256 royaltyValue  = harvestQty * 20 / 100; // 20% royalty to the initial owner
                 harvestQty = harvestQty - royaltyValue;      
                  if (royaltyValue != 0) {
                    _mint(initialOwner, royaltyValue); 
                  }
            }
        
            // Calculate the tenantShare from the 80% or 100%
            if(currentTenant != address(0))
            {
                uint256  ownershipLoyalty  = harvestQty * 10 / 100; // 10% royalty to the current owner
                uint256 tenantShare = harvestQty - ownershipLoyalty;      
                harvestQty = ownershipLoyalty;        // 10% from the (80% or 100%) of the original rewards
                
                _mint(currentTenant, tenantShare);  // 90% from the (80% or 100%) of the original rewards 
                
            }
            
            if (harvestQty != 0) {
                totalharvestQty = totalharvestQty.add(harvestQty);  // 80% to the current owner
                _lastharvest[tokenIndex] = block.timestamp;
            }
        }

        require(totalharvestQty != 0, "No SEEDs to harvest");
        
        _mint(owner, totalharvestQty); 
        return totalharvestQty;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        // Approval check is skipped if the caller of transferFrom is the Hashmasks contract. For better UX.
        if (msg.sender != _MarsPoolLandAddress) {
            _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        }
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    // ++
    /**
     * @dev Burns a quantity of tokens held by the caller.
     *
     * Emits an {Transfer} event to 0 address
     *
     */
    function burn(uint256 burnQuantity) public virtual override returns (bool) {
        _burn(msg.sender, burnQuantity);
        return true;
    }
    // ++

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}