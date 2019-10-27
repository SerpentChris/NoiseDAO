# Members can propose ways to spend funds and sponsor new members.
# Any member can veto a proposal or a sponsored member.
# Members can sponsor a new member or submit a proposal (not both) once a week.


struct Member:
    # sponsor is the address of the Member who sponsored this Member,
    sponsor: address
    # handle is a UTF8 encoded nickname that this Member goes by.
    handle: bytes32
    # time_joined is the timestamp of the block in which this member was sponsored.
    time_joined: timestamp
    # last_change is the timestamp of the block in which this member last sponsered a new member or made a new proposal.
    last_change: timestamp


struct Proposal:
    # sponsor is the address of the member who submitted this proposal
    sponsor: address
    # url is a link to the full proposal specification
    url: string[128]
    # digest is the sha3_256 digest of the proposal.
    digest: bytes32
    # wallet is the address to send funds to for this proposal.
    wallet: address
    # value is the amount of wei to send to the wallet
    value: uint256

NewMember: event({_sponsor: indexed(address), _address: indexed(address)})
NewProposal: event({_sponsor: indexed(address), _digest: indexed(bytes32)})
NewDonation: event({_donor: indexed(address), _value: indexed(uint256)})

# key for members is the member's address
members: public(map(address, Member))
handle_taken: public(map(bytes32, bool))
# key for proposals is the hash of the Proposal struct members.
proposals: public(map(bytes32, Proposal))

WEEK_IN_SECONDS: constant(timedelta) = 60*60*24*7


@private
def load_check_member(_address: address, current_time: timestamp) -> Member:
    member_data: Member = self.members[_address]
    assert(member_data.sponsor != ZERO_ADDRESS, 'address is not a member')
    assert((current_time - member_data.last_change) >= WEEK_IN_SECONDS, 'last change too recent')
    return member_data


@public
def sponsor_member(_address: address, _handle: bytes32):
    sponsor_address: address = msg.sender
    current_time: timestamp = block.timestamp
    sponsor: Member = self.load_check_member(sponsor_address, current_time)
    
    # make sure the proposed member address is not already used by a member
    assert(self.members[_address].sponsor == ZERO_ADDRESS, 'address already taken')
    # make sure the handle isn't already used
    assert(not self.handle_taken[_handle], 'handle already taken')

    self.members[_address] = Member(
        {
            sponsor: sponsor_address,
            handle: _handle,
            time_joined: current_time,
            last_change: 0,
        }
    )

    self.handle_taken[_handle] = True
    self.members[sponsor_addr].last_change = current_time
    log.NewMember(sponsor_addr, _address)


@private
def proposal_disgest(p: Proposal) -> bytes32:
    return keccak256(
        concat(
            convert(p.sponsor, bytes32),
            p.url,
            p.digest,
            convert(p.wallet, bytes32),
            convert(p.value, bytes32)
            )
    )


@public
def submit_proposal(_url: string[100], _digest: bytes32, _wallet: address, _value: uint256):
    sponsor_address: address = msg.sender
    current_time: timestamp = block.timestamp
    sponsor: Member = self.load_check_member(sponsor_address, current_time)

    p = Proposal({
        sponsor: sponsor_address,
        url: _url,
        digest: _digest,
        wallet: _wallet,
        value: _value
    })

    p_hash: bytes32 = self.proposal_digest(p)
    self.members[sponsor_address].last_change = block.timestamp
    self.proposals[p_hash] = p
    log.NewProposal(sponsor_address, p_hash)


@public
@payable
def donate():
    value = msg.value
    assert(value, 'empty donation')
    log.NewDonation(msg.sender, value)
