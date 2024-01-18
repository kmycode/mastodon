import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';


import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import AddIcon from '@/material-icons/400-24px/add.svg?react';
import CloseIcon from '@/material-icons/400-24px/close.svg?react';

import { removeFromAntennaEditor, addToAntennaEditor, removeExcludeFromAntennaEditor, addExcludeToAntennaEditor } from '../../../actions/antennas';
import { Avatar } from '../../../components/avatar';
import { DisplayName } from '../../../components/display_name';
import { IconButton } from '../../../components/icon_button';
import { makeGetAccount } from '../../../selectors';

const messages = defineMessages({
  remove: { id: 'antennas.account.remove', defaultMessage: 'Remove from antenna' },
  add: { id: 'antennas.account.add', defaultMessage: 'Add to antenna' },
});

const makeMapStateToProps = () => {
  const getAccount = makeGetAccount();

  const mapStateToProps = (state, { accountId, added }) => ({
    account: getAccount(state, accountId),
    added: typeof added === 'undefined' ? state.getIn(['antennaEditor', 'accounts', 'items']).includes(accountId) : added,
  });

  return mapStateToProps;
};

const mapDispatchToProps = (dispatch, { accountId }) => ({
  onRemove: () => dispatch(removeFromAntennaEditor(accountId)),
  onAdd: () => dispatch(addToAntennaEditor(accountId)),
  onExcludeRemove: () => dispatch(removeExcludeFromAntennaEditor(accountId)),
  onExcludeAdd: () => dispatch(addExcludeToAntennaEditor(accountId)),
});

class Account extends ImmutablePureComponent {

  static propTypes = {
    account: ImmutablePropTypes.map.isRequired,
    isExclude: PropTypes.bool.isRequired,
    intl: PropTypes.object.isRequired,
    onRemove: PropTypes.func.isRequired,
    onAdd: PropTypes.func.isRequired,
    onExcludeRemove: PropTypes.func.isRequired,
    onExcludeAdd: PropTypes.func.isRequired,
    added: PropTypes.bool,
  };

  static defaultProps = {
    added: false,
  };

  render () {
    const { account, intl, isExclude, onRemove, onAdd, onExcludeRemove, onExcludeAdd, added } = this.props;

    let button;

    if (added) {
      button = <IconButton icon='times' iconComponent={CloseIcon} title={intl.formatMessage(messages.remove)} onClick={isExclude ? onExcludeRemove : onRemove} />;
    } else {
      button = <IconButton icon='plus' iconComponent={AddIcon} title={intl.formatMessage(messages.add)} onClick={isExclude ? onExcludeAdd : onAdd} />;
    }

    return (
      <div className='account'>
        <div className='account__wrapper'>
          <div className='account__display-name'>
            <div className='account__avatar-wrapper'><Avatar account={account} size={36} /></div>
            <DisplayName account={account} />
          </div>

          <div className='account__relationship'>
            {button}
          </div>
        </div>
      </div>
    );
  }

}

export default connect(makeMapStateToProps, mapDispatchToProps)(injectIntl(Account));
