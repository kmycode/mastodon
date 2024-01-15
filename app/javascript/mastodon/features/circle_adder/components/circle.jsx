import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import CircleIcon from 'mastodon/../material-icons/400-24px/account_circle.svg?react';
import AddIcon from 'mastodon/../material-icons/400-24px/add.svg?react';
import CloseIcon from 'mastodon/../material-icons/400-24px/close.svg?react';
import { Icon }  from 'mastodon/components/icon';

import { removeFromCircleAdder, addToCircleAdder } from '../../../actions/circles';
import { IconButton }  from '../../../components/icon_button';

const messages = defineMessages({
  remove: { id: 'circles.account.remove', defaultMessage: 'Remove from circle' },
  add: { id: 'circles.account.add', defaultMessage: 'Add to circle' },
});

const MapStateToProps = (state, { circleId, added }) => ({
  circle: state.get('circles').get(circleId),
  added: typeof added === 'undefined' ? state.getIn(['circleAdder', 'circles', 'items']).includes(circleId) : added,
});

const mapDispatchToProps = (dispatch, { circleId }) => ({
  onRemove: () => dispatch(removeFromCircleAdder(circleId)),
  onAdd: () => dispatch(addToCircleAdder(circleId)),
});

class Circle extends ImmutablePureComponent {

  static propTypes = {
    circle: ImmutablePropTypes.map.isRequired,
    intl: PropTypes.object.isRequired,
    onRemove: PropTypes.func.isRequired,
    onAdd: PropTypes.func.isRequired,
    added: PropTypes.bool,
  };

  static defaultProps = {
    added: false,
  };

  render () {
    const { circle, intl, onRemove, onAdd, added } = this.props;

    let button;

    if (added) {
      button = <IconButton icon='times' iconComponent={CloseIcon} title={intl.formatMessage(messages.remove)} onClick={onRemove} />;
    } else {
      button = <IconButton icon='plus' iconComponent={AddIcon} title={intl.formatMessage(messages.add)} onClick={onAdd} />;
    }

    return (
      <div className='list'>
        <div className='list__wrapper'>
          <div className='list__display-name'>
            <Icon id='user-circle' icon={CircleIcon} className='column-link__icon' fixedWidth />
            {circle.get('title')}
          </div>

          <div className='account__relationship'>
            {button}
          </div>
        </div>
      </div>
    );
  }

}

export default connect(MapStateToProps, mapDispatchToProps)(injectIntl(Circle));
