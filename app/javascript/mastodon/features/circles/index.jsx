import PropTypes from 'prop-types';

import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';
import { createSelector } from 'reselect';

import { fetchCircles, deleteCircle } from 'mastodon/actions/circles';
import { openModal } from 'mastodon/actions/modal';
import Column from 'mastodon/components/column';
import ColumnHeader from 'mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import ScrollableList from 'mastodon/components/scrollable_list';
import ColumnLink from 'mastodon/features/ui/components/column_link';
import ColumnSubheading from 'mastodon/features/ui/components/column_subheading';

import NewCircleForm from './components/new_circle_form';

const messages = defineMessages({
  heading: { id: 'column.circles', defaultMessage: 'Circles' },
  subheading: { id: 'circles.subheading', defaultMessage: 'Your circles' },
  deleteMessage: { id: 'confirmations.delete_circle.message', defaultMessage: 'Are you sure you want to permanently delete this circle?' },
  deleteConfirm: { id: 'confirmations.delete_circle.confirm', defaultMessage: 'Delete' },
});

const getOrderedCircles = createSelector([state => state.get('circles')], circles => {
  if (!circles) {
    return circles;
  }

  return circles.toList().filter(item => !!item).sort((a, b) => a.get('title').localeCompare(b.get('title')));
});

const mapStateToProps = state => ({
  circles: getOrderedCircles(state),
});

class Circles extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    circles: ImmutablePropTypes.list,
    intl: PropTypes.object.isRequired,
    multiColumn: PropTypes.bool,
  };

  UNSAFE_componentWillMount () {
    this.props.dispatch(fetchCircles());
  }

  handleEditClick = (e) => {
    e.preventDefault();
    this.props.dispatch(openModal({
      modalType: 'CIRCLE_EDITOR',
      modalProps: { circleId: e.currentTarget.getAttribute('data-id') },
    }));
  };

  handleRemoveClick = (e) => {
    const { dispatch, intl } = this.props;

    e.preventDefault();
    const id = e.currentTarget.getAttribute('data-id');

    dispatch(openModal({
      modalType: 'CONFIRM',
      modalProps: {
        message: intl.formatMessage(messages.deleteMessage),
        confirm: intl.formatMessage(messages.deleteConfirm),
        onConfirm: () => {
          dispatch(deleteCircle(id));
        },
      },
    }));
  };

  render () {
    const { intl, circles, multiColumn } = this.props;

    if (!circles) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    const emptyMessage = <FormattedMessage id='empty_column.circles' defaultMessage="You don't have any circles yet. When you create one, it will show up here." />;

    return (
      <Column bindToDocument={!multiColumn} label={intl.formatMessage(messages.heading)}>
        <ColumnHeader title={intl.formatMessage(messages.heading)} icon='user-circle' multiColumn={multiColumn} />

        <NewCircleForm />

        <ScrollableList
          scrollKey='circles'
          emptyMessage={emptyMessage}
          prepend={<ColumnSubheading text={intl.formatMessage(messages.subheading)} />}
          bindToDocument={!multiColumn}
        >
          {circles.map(circle =>
            <ColumnLink key={circle.get('id')} to={`/circles/${circle.get('id')}`} icon='user-circle' text={circle.get('title')} />,
          )}
        </ScrollableList>

        <Helmet>
          <title>{intl.formatMessage(messages.heading)}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(Circles));
