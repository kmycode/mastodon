import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl } from '@/mastodon/components/intl';
import { FormattedMessage, defineMessages } from 'react-intl';


import { Helmet } from '@unhead/react/helmet';
import { withRouter } from 'react-router-dom';

import ImmutablePropTypes from 'react-immutable-proptypes';
import { connect } from 'react-redux';

import { fetchAntenna, deleteAntenna } from 'mastodon/actions/antennas';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { openModal } from 'mastodon/actions/modal';
import { connectAntennaStream } from 'mastodon/actions/streaming';
import { expandAntennaTimeline } from 'mastodon/actions/timelines';
import { Column } from 'mastodon/components/column';
import { ColumnHeader, ColumnSettingsMenu } from '@/mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import BundleColumnError from 'mastodon/features/ui/components/bundle_column_error';
import StatusListContainer from 'mastodon/features/ui/containers/status_list_container';
import { WithRouterPropTypes } from 'mastodon/utils/react_router';
import { MenuItem, MenuItemLink } from '@/mastodon/components/menu';
import { MultiColumnMenuItems } from '@/mastodon/components/column_header/multicolumn_settings';

const messages = defineMessages({
  deleteMessage: { id: 'confirmations.delete_antenna.message', defaultMessage: 'Are you sure you want to permanently delete this antenna?' },
  deleteConfirm: { id: 'confirmations.delete_antenna.confirm', defaultMessage: 'Delete' },
});

const mapStateToProps = (state, props) => ({
  antenna: state.getIn(['antennas', props.params.id]),
  hasUnread: state.getIn(['timelines', `antenna:${props.params.id}`, 'unread']) > 0,
});

class AntennaTimeline extends PureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    columnId: PropTypes.string,
    hasUnread: PropTypes.bool,
    multiColumn: PropTypes.bool,
    antenna: PropTypes.oneOfType([ImmutablePropTypes.map, PropTypes.bool]),
    intl: PropTypes.object.isRequired,
    ...WithRouterPropTypes,
  };

  handlePin = () => {
    const { columnId, dispatch } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('ANTENNA_TIMELINE', { id: this.props.params.id }));
      this.props.history.push('/');
    }
  };

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  };

  handleHeaderClick = () => {
    this.column.scrollTop();
  };

  componentDidMount () {
    const { dispatch } = this.props;
    const { id } = this.props.params;

    dispatch(fetchAntenna(id));
    dispatch(expandAntennaTimeline(id));

    this.disconnect = dispatch(connectAntennaStream(id));
  }

  UNSAFE_componentWillReceiveProps (nextProps) {
    const { dispatch } = this.props;
    const { id } = nextProps.params;

    if (id !== this.props.params.id) {
      if (this.disconnect) {
        this.disconnect();
        this.disconnect = null;
      }

      dispatch(fetchAntenna(id));
      dispatch(expandAntennaTimeline(id));

      this.disconnect = dispatch(connectAntennaStream(id));
    }
  }

  componentWillUnmount () {
    if (this.disconnect) {
      this.disconnect();
      this.disconnect = null;
    }
  }

  setRef = c => {
    this.column = c;
  };

  handleLoadMore = maxId => {
    const { id } = this.props.params;
    this.props.dispatch(expandAntennaTimeline(id, { maxId }));
  };

  handleEditClick = () => {
    this.props.history.push(`/antennas/${this.props.params.id}/edit`);
  };

  handleDeleteClick = () => {
    const { dispatch, columnId, intl } = this.props;
    const { id } = this.props.params;

    dispatch(openModal({
      modalType: 'CONFIRM',
      modalProps: {
        message: intl.formatMessage(messages.deleteMessage),
        confirm: intl.formatMessage(messages.deleteConfirm),
        onConfirm: () => {
          dispatch(deleteAntenna(id));

          if (columnId) {
            dispatch(removeColumn(columnId));
          } else {
            this.props.history.push('/antennasw');
          }
        },
      },
    }));
  };

  render () {
    const { columnId, multiColumn, antenna } = this.props;
    const { id } = this.props.params;
    const pinned = !!columnId;
    const title  = antenna ? antenna.get('title') : id;

    if (typeof antenna === 'undefined') {
      return (
        <Column>
          <div className='scrollable'>
            <LoadingIndicator />
          </div>
        </Column>
      );
    } else if (antenna === false) {
      return (
        <BundleColumnError multiColumn={multiColumn} errorType='routing' />
      );
    }

    return (
      <Column bindToDocument={!multiColumn} ref={this.setRef} label={title}>
        <ColumnHeader
          title={title}
          withBackButton={multiColumn && !pinned && 'auto'}
          extraButtons={(
            <ColumnSettingsMenu
              label={
                <FormattedMessage id='antennas.options' defaultMessage='Antenna Options' />
              }
            >
              <MenuItemLink as='link' to={`/antennas/${id}/edit`}>
                <FormattedMessage id='antennas.edit' defaultMessage='Edit antenna' />
              </MenuItemLink>
              <MenuItem onClick={this.handleDeleteClick}>
                <FormattedMessage id='antennas.delete' defaultMessage='Delete antenna' />
              </MenuItem>

              {multiColumn &&
                <MultiColumnMenuItems
                  withDivider
                  pinned={pinned}
                  onPin={this.handlePin}
                  onMove={this.handleMove}
                />
              }
            </ColumnSettingsMenu>
          )}
        />

        <StatusListContainer
          trackScroll={!pinned}
          scrollKey={`antenna_timeline-${columnId}`}
          timelineId={`antenna:${id}`}
          onLoadMore={this.handleLoadMore}
          emptyMessage={<FormattedMessage id='empty_column.antenna' defaultMessage='There is nothing in this antenna yet. When members of this list post new statuses, they will appear here.' />}
          bindToDocument={!multiColumn}
        />

        <Helmet>
          <title>{title}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default withRouter(connect(mapStateToProps)(injectIntl(AntennaTimeline)));
