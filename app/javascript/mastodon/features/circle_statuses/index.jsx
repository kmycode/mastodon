import PropTypes from 'prop-types';

import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import { debounce } from 'lodash';

import { deleteCircle, expandCircleStatuses, fetchCircle, fetchCircleStatuses } from 'mastodon/actions/circles';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { openModal } from 'mastodon/actions/modal';
import Column from 'mastodon/components/column';
import ColumnHeader from 'mastodon/components/column_header';
import { Icon }  from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import StatusList from 'mastodon/components/status_list';
import BundleColumnError from 'mastodon/features/ui/components/bundle_column_error';
import { getCircleStatusList } from 'mastodon/selectors';


const messages = defineMessages({
  deleteMessage: { id: 'confirmations.delete_circle.message', defaultMessage: 'Are you sure you want to permanently delete this circle?' },
  deleteConfirm: { id: 'confirmations.delete_circle.confirm', defaultMessage: 'Delete' },
  heading: { id: 'column.circles', defaultMessage: 'Circles' },
});

const mapStateToProps = (state, { params }) => ({
  circle: state.getIn(['circles', params.id]),
  statusIds: getCircleStatusList(state, params.id),
  isLoading: state.getIn(['circles', params.id, 'isLoading'], true),
  isEditing: state.getIn(['circleEditor', 'circleId']) === params.id,
  hasMore: !!state.getIn(['circles', params.id, 'next']),
});

class CircleStatuses extends ImmutablePureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    statusIds: ImmutablePropTypes.list.isRequired,
    circle: PropTypes.oneOfType([ImmutablePropTypes.map, PropTypes.bool]),
    intl: PropTypes.object.isRequired,
    columnId: PropTypes.string,
    multiColumn: PropTypes.bool,
    hasMore: PropTypes.bool,
    isLoading: PropTypes.bool,
  };

  UNSAFE_componentWillMount () {
    this.props.dispatch(fetchCircle(this.props.params.id));
    this.props.dispatch(fetchCircleStatuses(this.props.params.id));
  }

  handlePin = () => {
    const { columnId, dispatch } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('CIRCLE_STATUSES', { id: this.props.params.id }));
      this.context.router.history.push('/');
    }
  };

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  };

  handleHeaderClick = () => {
    this.column.scrollTop();
  };

  handleEditClick = () => {
    this.props.dispatch(openModal({
      modalType: 'CIRCLE_EDITOR',
      modalProps: { circleId: this.props.params.id },
    }));
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
          dispatch(deleteCircle(id));

          if (columnId) {
            dispatch(removeColumn(columnId));
          } else {
            this.context.router.history.push('/circles');
          }
        },
      },
    }));
  };

  setRef = c => {
    this.column = c;
  };

  handleLoadMore = debounce(() => {
    this.props.dispatch(expandCircleStatuses());
  }, 300, { leading: true });

  render () {
    const { intl, circle, statusIds, columnId, multiColumn, hasMore, isLoading } = this.props;
    const pinned = !!columnId;

    if (typeof circle === 'undefined') {
      return (
        <Column>
          <div className='scrollable'>
            <LoadingIndicator />
          </div>
        </Column>
      );
    } else if (circle === false) {
      return (
        <BundleColumnError multiColumn={multiColumn} errorType='routing' />
      );
    }

    const emptyMessage = <FormattedMessage id='empty_column.circle_statuses' defaultMessage="You don't have any circle posts yet. When you post one as circle, it will show up here." />;

    return (
      <Column bindToDocument={!multiColumn} ref={this.setRef} label={intl.formatMessage(messages.heading)}>
        <ColumnHeader
          icon='user-circle'
          title={circle.get('title')}
          onPin={this.handlePin}
          onMove={this.handleMove}
          onClick={this.handleHeaderClick}
          pinned={pinned}
          multiColumn={multiColumn}
        >
          <div className='column-settings__row column-header__links'>
            <button type='button' className='text-btn column-header__setting-btn' tabIndex={0} onClick={this.handleEditClick}>
              <Icon id='pencil' /> <FormattedMessage id='circles.edit' defaultMessage='Edit circle' />
            </button>

            <button type='button' className='text-btn column-header__setting-btn' tabIndex={0} onClick={this.handleDeleteClick}>
              <Icon id='trash' /> <FormattedMessage id='circles.delete' defaultMessage='Delete circle' />
            </button>
          </div>
        </ColumnHeader>

        <StatusList
          trackScroll={!pinned}
          statusIds={statusIds}
          scrollKey={`circle_statuses-${columnId}`}
          hasMore={hasMore}
          isLoading={isLoading}
          onLoadMore={this.handleLoadMore}
          emptyMessage={emptyMessage}
          bindToDocument={!multiColumn}
        />

        <Helmet>
          <title>{intl.formatMessage(messages.heading)}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(CircleStatuses));
