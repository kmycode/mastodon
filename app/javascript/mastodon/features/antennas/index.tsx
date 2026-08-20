import { useEffect, useMemo, useCallback } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import { Helmet } from '@unhead/react/helmet';

import { NotSignedInIndicator } from '@/mastodon/components/not_signed_in_indicator';
import { useIdentity } from '@/mastodon/identity_context';
import AddIcon from '@/material-icons/400-24px/add.svg?react';
import MoreHorizIcon from '@/material-icons/400-24px/more_horiz.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import SquigglyArrow from '@/svg-icons/squiggly_arrow.svg?react';
import { fetchAntennas } from 'mastodon/actions/antennas';
import { openModal } from 'mastodon/actions/modal';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column/header';
import { Dropdown } from 'mastodon/components/dropdown_menu';
import { Icon } from 'mastodon/components/icon';
import ScrollableList from 'mastodon/components/scrollable_list';
import { getOrderedAntennas } from 'mastodon/selectors/antennas';
import { useAppSelector, useAppDispatch } from 'mastodon/store';

const messages = defineMessages({
  heading: { id: 'column.antennas', defaultMessage: 'Antennas' },
  create: { id: 'antennas.create_antenna', defaultMessage: 'Create antenna' },
  edit: { id: 'antennas.edit', defaultMessage: 'Edit antenna' },
  delete: { id: 'antennas.delete', defaultMessage: 'Delete antenna' },
  more: { id: 'status.more', defaultMessage: 'More' },
});

const AntennaItem: React.FC<{
  id: string;
  title: string;
  insert_feeds: boolean;
  isList: boolean;
  listTitle?: string;
  stl: boolean;
  ltl: boolean;
}> = ({ id, title, insert_feeds, isList, listTitle, stl, ltl }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();

  const handleDeleteClick = useCallback(() => {
    dispatch(
      openModal({
        modalType: 'CONFIRM_DELETE_ANTENNA',
        modalProps: {
          antennaId: id,
        },
      }),
    );
  }, [dispatch, id]);

  const menu = useMemo(
    () => [
      { text: intl.formatMessage(messages.edit), to: `/antennas/${id}/edit` },
      { text: intl.formatMessage(messages.delete), action: handleDeleteClick },
    ],
    [intl, id, handleDeleteClick],
  );

  return (
    <div className='lists__item'>
      <Link to={`/antennas/${id}`} className='lists__item__title'>
        <Icon id='antenna-ul' icon={AntennaIcon} />
        <span>
          {title}

          {stl && (
            <span className='column-link__badge'>
              <FormattedMessage id='antennas.badge_stl' defaultMessage='STL' />
            </span>
          )}
          {ltl && (
            <span className='column-link__badge'>
              <FormattedMessage id='antennas.badge_ltl' defaultMessage='LTL' />
            </span>
          )}

          {insert_feeds && (
            <span className='lists__item__memo'>
              {isList && listTitle && (
                <FormattedMessage
                  id='antennas.memo_insert_list'
                  defaultMessage='List: "{title}"'
                  values={{ title: listTitle }}
                />
              )}
              {!isList && (
                <FormattedMessage
                  id='antennas.memo_insert_home'
                  defaultMessage='Inserts home timeline.'
                />
              )}
            </span>
          )}
        </span>
      </Link>

      <Dropdown
        scrollKey='antennas'
        items={menu}
        icon='ellipsis-h'
        iconComponent={MoreHorizIcon}
        title={intl.formatMessage(messages.more)}
      />
    </div>
  );
};

const Antennas: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();
  const antennas = useAppSelector((state) => getOrderedAntennas(state));
  const { signedIn } = useIdentity();

  useEffect(() => {
    if (signedIn) {
      void dispatch(fetchAntennas());
    }
  }, [signedIn, dispatch]);

  const emptyMessage = (
    <>
      <span>
        <FormattedMessage
          id='antennas.no_antennas_yet'
          defaultMessage='No antennas yet.'
        />
        <br />
        <FormattedMessage
          id='antennas.create_a_antenna_to_organize'
          defaultMessage='Create a new antenna to organize your Home feed'
        />
      </span>

      <SquigglyArrow className='empty-column-indicator__arrow' />
    </>
  );

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(messages.heading)}
    >
      <ColumnHeader
        title={intl.formatMessage(messages.heading)}
        icon='antenna-ul'
        iconComponent={AntennaIcon}
        multiColumn={multiColumn}
        extraButton={
          signedIn && (
            <Link
              to='/antennas/new'
              className='column-header__button'
              title={intl.formatMessage(messages.create)}
              aria-label={intl.formatMessage(messages.create)}
            >
              <Icon id='plus' icon={AddIcon} />
            </Link>
          )
        }
      />

      <ScrollableList
        scrollKey='antennas'
        emptyMessage={emptyMessage}
        bindToDocument={!multiColumn}
      >
        {signedIn ? (
          antennas.map((antenna) => (
            <AntennaItem
              key={antenna.id}
              id={antenna.id}
              title={antenna.title}
              insert_feeds={antenna.insert_feeds}
              isList={!!antenna.list}
              listTitle={antenna.list?.title}
              stl={antenna.stl}
              ltl={antenna.ltl}
            />
          ))
        ) : (
          <NotSignedInIndicator />
        )}
      </ScrollableList>

      <Helmet>
        <title>{intl.formatMessage(messages.heading)}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default Antennas;
