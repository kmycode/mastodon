import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import AddIcon from '@/material-icons/400-24px/add.svg?react';
import CloseIcon from '@/material-icons/400-24px/close.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { Icon }  from 'mastodon/components/icon';

import { removeFromAntennaAdder, addToAntennaAdder, removeExcludeFromAntennaAdder, addExcludeToAntennaAdder } from '../../../actions/antennas';
import { IconButton }  from '../../../components/icon_button';

const messages = defineMessages({
  remove: { id: 'antennas.account.remove', defaultMessage: 'Remove from antenna' },
  add: { id: 'antennas.account.add', defaultMessage: 'Add to antenna' },
});

const MapStateToProps = (state, { antennaId, added }) => ({
  antenna: state.get('antennas').get(antennaId),
  added: typeof added === 'undefined' ? state.getIn(['antennaAdder', 'antennas', 'items']).includes(antennaId) : added,
});

const mapDispatchToProps = (dispatch, { antennaId }) => ({
  onRemove: () => dispatch(removeFromAntennaAdder(antennaId)),
  onAdd: () => dispatch(addToAntennaAdder(antennaId)),
  onExcludeRemove: () => dispatch(removeExcludeFromAntennaAdder(antennaId)),
  onExcludeAdd: () => dispatch(addExcludeToAntennaAdder(antennaId)),
});

class Antenna extends ImmutablePureComponent {

  static propTypes = {
    antenna: ImmutablePropTypes.map.isRequired,
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

  handleRemove = () => {
    if (this.props.isExclude) {
      this.props.onExcludeRemove();
    } else {
      this.props.onRemove();
    }
  };

  handleAdd = () => {
    if (this.props.isExclude) {
      this.props.onExcludeAdd();
    } else {
      this.props.onAdd();
    }
  };

  render () {
    const { antenna, intl, added } = this.props;

    let button;

    if (added) {
      button = <IconButton icon='times' iconComponent={CloseIcon} title={intl.formatMessage(messages.remove)} onClick={this.handleRemove} />;
    } else {
      button = <IconButton icon='plus' iconComponent={AddIcon} title={intl.formatMessage(messages.add)} onClick={this.handleAdd} />;
    }

    return (
      <div className='list'>
        <div className='list__wrapper'>
          <div className='list__display-name'>
            <Icon id='wifi' icon={AntennaIcon} className='column-link__icon' fixedWidth />
            {antenna.get('title')}
          </div>

          <div className='account__relationship'>
            {button}
          </div>
        </div>
      </div>
    );
  }

}

export default connect(MapStateToProps, mapDispatchToProps)(injectIntl(Antenna));
