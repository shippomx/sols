// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "./utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    address private _owner;
    //开始时间,只能大于当前时间
    uint256 _startTime;
    uint256 immutable baseInterval = 1 days;
    mapping(uint8 => OrgRecord) orgRecord;

    mapping(uint8 => address[]) orgWallet;
    mapping(address => WalletRecord) walletRecords;

    event Organization(uint8 indexed organizationId, uint256 releaseAllTime);
    event ChangeOwner(address indexed oldOwner, address indexed newOwner);
    //1
    uint256[5] orgOne = [0 * 10**18, 0, 30, 30, 100];
    //2
    uint256[5] orgTwo   = [0 * 10**18, 100, 6 * 30, 3 * 30, 250];
    //IDO3
    uint256[5] orgThree = [150000000 * 10**18, 0, 0 * 30, 3 * 30, 250];
    //team4
    uint256[5] orgFour = [150000000 * 10**18, 0, 12 * 30, 3 * 30, 125];
    //社区分红5
    uint256[5] orgFive = [300000000 * 10**18, 0, 12 * 30, 3 * 30, 125];
    //玩家奖励6，流动
    uint256[5] orgSix = [1800000000 * 10**18, 1000, 0, 0, 0];
    //平台发展和生态基金7，流动
    uint256[5] orgSeven = [600000000 * 10**18, 1000, 0, 0, 0];
    uint256[5][7] orgRecords = [
        orgOne,
        orgTwo,
        orgThree,
        orgFour,
        orgFive,
        orgSix,
        orgSeven
    ];
    //机构具体信息
    struct OrgRecord {
        //机构总发放量
        uint256 orgTotal;
        //机构剩余发放量
        uint256 orgBalance;
    }
    //钱包锁仓具体信息
    struct WalletRecord {
        //钱包锁仓总数
        uint256 lockTotal;
        //剩余锁仓数量
        uint256 lockBalanceNum;
        //机构索引
        uint8 index;
        //初始解锁千分比（默认千分比）
        uint256 firstUnlockPre;
        //初始释放间隔
        uint256 releaseInterval;
        // 初始释放间隔时间之后每次释放的间隔时间（day）
        uint256 intervalTime;
        // 以后每次释放的千分比（默认千分比）
        uint256 secondUnlockPre;
        //最近一次释放的时间
        uint256 lastRelease;
        //释放完成的最后时间
        uint256 releaseAllTime;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "not onwer");
        _;
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _owner = msg.sender;
        //设置机构信息
        for (uint8 i = 0; i < orgRecords.length; i++) {
            uint8 x = i + 1;
            orgRecord[x].orgTotal = orgRecords[i][0];
            orgRecord[x].orgBalance = orgRecords[i][0];
        }
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
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
    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

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
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    //钱包剩余锁仓量
    function lockNum(address account) external view returns (uint256) {
        uint256 balanceLockNum = _releaseTokenSearch(account);

        return balanceLockNum;
    }

    //钱包总锁仓量
    function totalLock(address account) external view returns (uint256) {
        return walletRecords[account].lockTotal;
    }

    //开始时间
    function searchStartTime() external view returns (uint256) {
        return _startTime;
    }

    //机构下的钱包
    function wallets(uint8 index)
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        return orgWallet[index];
    }

    //钱包所属机构
    function belongOrg(address account) external view returns (uint8) {
        return walletRecords[account].index;
    }

    //查询合约拥有者
    function searchOwner() external view returns (address) {
        return _owner;
    }

    //修改合约拥有者
    function changeOwner(address account) external onlyOwner {
        emit ChangeOwner(_owner, account);
        _owner = account;
    }

    //设置活动的开始时间
    function setStartTime(uint256 startTime) external onlyOwner {
        require(_startTime == 0, "startTime exist");
        require(startTime >= block.timestamp, "time error");
        _startTime = startTime;
        //遍历已存在的所有数据，并开始分发
        for (uint8 i = 0; i < 5; i++) {
            uint256 _releaseAllTime;
            (_releaseAllTime, , , , ) = _releaseAll(orgRecords[i]);
            uint8 y = i + 1;
            for (uint8 x = 0; x < orgWallet[y].length; x++) {
                if (orgWallet[y].length != 0) {
                    walletRecords[orgWallet[y][x]]
                        .releaseAllTime = _releaseAllTime;
                    _releaseToken(orgWallet[y][x], true);
                }
            }
        }
    }

    /**
     添加管理机构及其对应token数量
    _organizationId:机构id
    _walletArray：对应机构的钱包地址数组
    _amountArray：对应机构的钱包地址token数量
    _firstUnlockPre：初始解锁千分比（默认千分比）
    _releaseInterval:初始释放间隔时间（day）
    _intervalTime:初始释放间隔时间之后每次释放的间隔时间（day）
    _secondUnlockPre: 以后每次释放的千分比（默认千分比）
    所有机构之间的钱包不能重复
     */
    function setOrganization(
        uint8 _organizationId,
        address[] memory _walletArray,
        uint256[] memory _amountArray
    ) external onlyOwner {
        require(_organizationId != 0, "orgid is zero");
        require(_walletArray.length == _amountArray.length, "length error");
        uint8 organizationId = _organizationId - 1;

        //判断机构是否存在，如果存在判断是否超过机构总额，没超过继续添加
        uint256 orgTotal;
        OrgRecord storage oneOrgRecord = orgRecord[_organizationId];
        for (uint256 i = 0; i < _amountArray.length; i++) {
            orgTotal += _amountArray[i];
        }
        require(oneOrgRecord.orgBalance >= orgTotal, "total error");
        oneOrgRecord.orgBalance = oneOrgRecord.orgBalance - orgTotal;
        uint256 _releaseAllTime;
        uint256 _releaseIntervalValue;
        uint256 _intervalTimeValue;
        uint256 _firstUnlockPre;
        uint256 _secondUnlockPre;

        (
            _releaseAllTime,
            _releaseIntervalValue,
            _intervalTimeValue,
            _firstUnlockPre,
            _secondUnlockPre
        ) = _releaseAll(orgRecords[organizationId]);

        for (uint256 i = 0; i < _walletArray.length; i++) {
            orgWallet[_organizationId].push(_walletArray[i]);
            walletRecords[_walletArray[i]] = WalletRecord(
                _amountArray[i],
                _amountArray[i],
                _organizationId,
                _firstUnlockPre,
                _releaseIntervalValue,
                _intervalTimeValue,
                _secondUnlockPre,
                0,
                _releaseAllTime
            );
            _transfer(_owner, _walletArray[i], _amountArray[i]);
        }
        emit Organization(_organizationId, _releaseAllTime);
    }

    //统计锁仓的数量
    function _releaseToken(address account, bool isSetTime) private {
        WalletRecord storage walletRecorde = walletRecords[account];
        uint8 _organizationId = walletRecorde.index;
        if (
            _organizationId == 0 || walletRecords[account].lockBalanceNum == 0
        ) {
            return;
        }
        uint256 nowTime = block.timestamp;

        if (
            _organizationId != 6 && _organizationId != 7 && _organizationId != 0
        ) {
            require(_startTime != 0, "no start time");
            //如果是设置时间，那么设置的时间必须大于当前时间
            if (isSetTime) {
                require(nowTime < _startTime, "not initial time");
                return;
            }
        }

        //因为释放是根据千分比，所以统计其中一个即可
        require(walletRecorde.lockBalanceNum != 0, "all released");
        //判断是否仅在初始释放时间内
        uint256 lockBalanceValue = _lockBalanceNum(walletRecorde, nowTime);
        walletRecorde.lockBalanceNum = lockBalanceValue;
        walletRecorde.lastRelease = nowTime;
    }

    //查询剩余锁仓量
    function _releaseTokenSearch(address account)
        private
        view
        returns (uint256)
    {
        WalletRecord storage walletRecorde = walletRecords[account];
        uint8 _organizationId = walletRecorde.index;
        if (_organizationId == 0 || walletRecorde.lockBalanceNum == 0) {
            return 0;
        }

        uint256 nowTime = block.timestamp;
        uint256 lockTotalValue = walletRecorde.lockTotal;

        if (
            _organizationId != 6 &&
            _organizationId != 7 &&
            (_startTime == 0 || nowTime < _startTime)
        ) {
            return lockTotalValue;
        }

        return _lockBalanceNum(walletRecorde, nowTime);
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        //部署合约的地址只能转给机构下的钱包,且只能转一次
        if (from == _owner) {
            require(
                walletRecords[to].index != 0 &&
                    walletRecords[to].lastRelease == 0,
                "can not tx"
            );
        }
        _releaseToken(from, false);

        uint256 fromBalance = _balances[from];
        uint256 lockBalanceNumValue = walletRecords[from].lockBalanceNum;
        require(fromBalance - lockBalanceNumValue >= amount, "not enough");

        _beforeTokenTransfer(from, to, amount);

        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
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

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    //计算全部释放完成的时间
    function _releaseAll(uint256[5] storage oneOrgRecordMsg)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 _firstUnlockPre = oneOrgRecordMsg[1];
        //初始释放间隔
        uint256 _releaseInterval = oneOrgRecordMsg[2].mul(baseInterval);
        //之后释放间隔
        uint256 _intervalTime = oneOrgRecordMsg[3].mul(baseInterval);
        uint256 _secondUnlockPre = oneOrgRecordMsg[4];

        if (_secondUnlockPre == 0) {
            return (
                _startTime,
                _releaseInterval,
                _intervalTime,
                _firstUnlockPre,
                _secondUnlockPre
            );
        }
        uint256 baseNum = 1000;
        uint256 firstBalance = baseNum.sub(_firstUnlockPre);
        //第二次发放的总次数
        uint256 times = (firstBalance.sub(firstBalance.mod(_secondUnlockPre)))
            .div(_secondUnlockPre);
        uint256 _releaseAllTimes = _startTime.add(_releaseInterval).add(
            times.mul(_intervalTime)
        );
        return (
            _releaseAllTimes,
            _releaseInterval,
            _intervalTime,
            _firstUnlockPre,
            _secondUnlockPre
        );
    }

    //计算钱包的锁定余额
    function _lockBalanceNum(
        WalletRecord storage walletRecorde,
        uint256 nowTime
    ) private view returns (uint256) {
        /**因为释放是根据千分比，所以统计其中一个即可
        //判断是否仅在初始释放时间内
        判断是否是初次释放
        */
        uint256 lastTime;
        uint256 duration;
        //初次释放(证明还有初始释放)
        if (walletRecorde.lastRelease == 0) {
            //在初始间隔时间内
            if (walletRecorde.releaseInterval.add(_startTime) > nowTime) {
                return
                    walletRecorde.lockBalanceNum.sub(
                        walletRecorde
                            .lockTotal
                            .mul(walletRecorde.firstUnlockPre)
                            .div(1000)
                    );
            } else {
                //释放完全部
                if (nowTime > walletRecorde.releaseAllTime) {
                    return 0;
                } else {
                    //在第二次间隔时间
                    lastTime = _startTime.add(walletRecorde.releaseInterval);
                    duration = nowTime.sub(lastTime);
                    uint256 times = (
                        duration.sub(duration.mod(walletRecorde.intervalTime))
                    ).div(walletRecorde.intervalTime).add(1);

                    return
                        walletRecorde.lockBalanceNum.sub(
                            walletRecorde
                                .lockTotal
                                .mul(
                                    walletRecorde.firstUnlockPre.add(
                                        times.mul(walletRecorde.secondUnlockPre)
                                    )
                                )
                                .div(1000)
                        );
                }
            }
        } else {
            //释放完全部
            if (nowTime > walletRecorde.releaseAllTime) {
                return 0;
            } else {
                //在第二次间隔时间
                duration = nowTime.sub(walletRecorde.lastRelease);
                uint256 times = (
                    (duration.sub(duration.mod(walletRecorde.intervalTime)))
                ).div(walletRecorde.intervalTime).add(1);

                return
                    walletRecorde.lockBalanceNum.sub(
                        times.mul(
                            walletRecorde
                                .lockTotal
                                .mul(walletRecorde.secondUnlockPre)
                                .div(1000)
                        )
                    );
            }
        }
    }
}
