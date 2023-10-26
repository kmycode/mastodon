import PropTypes from 'prop-types';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';
import { createSelector } from 'reselect';

import { fetchAntennas } from 'mastodon/actions/antennas';
import { fetchLists } from 'mastodon/actions/lists';

import ColumnLink from './column_link';

const getOrderedLists = createSelector([state => state.get('lists')], lists => {
  if (!lists) {
    return lists;
  }

  return lists.toList().filter(item => !!item).sort((a, b) => a.get('title').localeCompare(b.get('title'))).take(8);
});

const getOrderedAntennas = createSelector([state => state.get('antennas')], antennas => {
  if (!antennas) {
    return antennas;
  }

  return antennas.toList().filter(item => !!item && !item.get('insert_feeds')).sort((a, b) => a.get('title').localeCompare(b.get('title'))).take(8);
});

const mapStateToProps = state => ({
  lists: getOrderedLists(state),
  antennas: getOrderedAntennas(state),
});

class ListPanel extends ImmutablePureComponent {

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
    lists: ImmutablePropTypes.list,
    antennas: ImmutablePropTypes.list,
  };

  componentDidMount () {
    const { dispatch } = this.props;
    dispatch(fetchLists());
    dispatch(fetchAntennas());
  }

  render () {
    const { lists, antennas } = this.props;
    const size = (lists ? lists.size : 0) + (antennas ? antennas.size : 0);

    if (size === 0) {
      return null;
    }

    return (
      <div className='list-panel'>
        <hr />

        {lists && lists.map(list => (
          <ColumnLink icon='list-ul' key={list.get('id')} strict text={list.get('title')} to={`/lists/${list.get('id')}`} transparent />
        ))}
        {antennas && antennas.take(8 - (lists ? lists.size : 0)).map(antenna => (
          <ColumnLink icon='wifi' key={antenna.get('id')} strict text={antenna.get('title')} to={`/antennast/${antenna.get('id')}`} transparent />
        ))}
      </div>
    );
  }

}

export default connect(mapStateToProps)(ListPanel);
