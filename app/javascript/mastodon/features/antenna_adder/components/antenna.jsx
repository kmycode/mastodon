import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import { Icon } from 'mastodon/components/icon';

import { removeFromAntennaAdder, addToAntennaAdder } from '../../../actions/antennas';
import { IconButton } from '../../../components/icon_button';

const messages = defineMessages({
  remove: { id: 'lists.account.remove', defaultMessage: 'Remove from list' },
  add: { id: 'lists.account.add', defaultMessage: 'Add to list' },
});

const MapStateToProps = (state, { antennaId, added }) => ({
  antenna: state.get('antennas').get(antennaId),
  added: typeof added === 'undefined' ? state.getIn(['antennaAdder', 'antennas', 'items']).includes(antennaId) : added,
});

const mapDispatchToProps = (dispatch, { antennaId }) => ({
  onRemove: () => dispatch(removeFromAntennaAdder(antennaId)),
  onAdd: () => dispatch(addToAntennaAdder(antennaId)),
});

class Antenna extends ImmutablePureComponent {

  static propTypes = {
    antenna: ImmutablePropTypes.map.isRequired,
    intl: PropTypes.object.isRequired,
    onRemove: PropTypes.func.isRequired,
    onAdd: PropTypes.func.isRequired,
    added: PropTypes.bool,
  };

  static defaultProps = {
    added: false,
  };

  render () {
    const { antenna, intl, onRemove, onAdd, added } = this.props;

    let button;

    if (added) {
      button = <IconButton icon='times' title={intl.formatMessage(messages.remove)} onClick={onRemove} />;
    } else {
      button = <IconButton icon='plus' title={intl.formatMessage(messages.add)} onClick={onAdd} />;
    }

    return (
      <div className='list'>
        <div className='list__wrapper'>
          <div className='list__display-name'>
            <Icon id='wifi' className='column-link__icon' fixedWidth />
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
