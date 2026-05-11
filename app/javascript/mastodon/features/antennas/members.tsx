import { useCallback, useState, useEffect, useRef } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';
import { useParams, Link } from 'react-router-dom';

import { useDebouncedCallback } from 'use-debounce';

import AddIcon from '@/material-icons/400-24px/add.svg?react';
import ArrowBackIcon from '@/material-icons/400-24px/arrow_back.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import SquigglyArrow from '@/svg-icons/squiggly_arrow.svg?react';
import { fetchFollowing } from 'mastodon/actions/accounts';
import { fetchAntenna } from 'mastodon/actions/antennas';
import { importFetchedAccounts } from 'mastodon/actions/importer';
import { apiRequest } from 'mastodon/api';
import {
  apiGetAccounts,
  apiAddAccountToAntenna,
  apiRemoveAccountFromAntenna,
  apiRemoveExcludeAccountFromAntenna,
  apiAddExcludeAccountToAntenna,
  apiGetExcludeAccounts,
} from 'mastodon/api/antennas';
import type { ApiAccountJSON } from 'mastodon/api_types/accounts';
import { Avatar } from 'mastodon/components/avatar';
import { VerifiedBadge } from 'mastodon/components/badge';
import { Button } from 'mastodon/components/button';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { FollowersCounter } from 'mastodon/components/counters';
import { DisplayName } from 'mastodon/components/display_name';
import { Icon } from 'mastodon/components/icon';
import ScrollableList from 'mastodon/components/scrollable_list';
import { ShortNumber } from 'mastodon/components/short_number';
import { ButtonInTabsBar } from 'mastodon/features/ui/util/columns_context';
import { me } from 'mastodon/initial_state';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  heading: {
    id: 'column.antenna_members',
    defaultMessage: 'Manage antenna members',
  },
  placeholder: {
    id: 'antennas.search_placeholder',
    defaultMessage: 'Search people you follow',
  },
  enterSearch: {
    id: 'antennas.add_to_antenna',
    defaultMessage: 'Add to antenna',
  },
  add: { id: 'antennas.add_member', defaultMessage: 'Add' },
  remove: { id: 'antennas.remove_member', defaultMessage: 'Remove' },
  back: { id: 'column_back_button.label', defaultMessage: 'Back' },
});

type Mode = 'remove' | 'add';

const ColumnSearchHeader: React.FC<{
  onBack: () => void;
  onSubmit: (value: string) => void;
}> = ({ onBack, onSubmit }) => {
  const intl = useIntl();
  const [value, setValue] = useState('');

  const handleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setValue(value);
      onSubmit(value);
    },
    [setValue, onSubmit],
  );

  const handleSubmit = useCallback(() => {
    onSubmit(value);
  }, [onSubmit, value]);

  return (
    <ButtonInTabsBar>
      <form className='column-search-header' onSubmit={handleSubmit}>
        <button
          type='button'
          className='column-header__back-button compact'
          onClick={onBack}
          aria-label={intl.formatMessage(messages.back)}
        >
          <Icon
            id='chevron-left'
            icon={ArrowBackIcon}
            className='column-back-button__icon'
          />
        </button>

        <input
          type='search'
          value={value}
          onChange={handleChange}
          placeholder={intl.formatMessage(messages.placeholder)}
          /* eslint-disable-next-line jsx-a11y/no-autofocus */
          autoFocus
        />
      </form>
    </ButtonInTabsBar>
  );
};

const AccountItem: React.FC<{
  accountId: string;
  antennaId: string;
  partOfAntenna: boolean;
  isExclude?: boolean;
  onToggle: (accountId: string) => void;
}> = ({ accountId, antennaId, partOfAntenna, isExclude, onToggle }) => {
  const intl = useIntl();
  const account = useAppSelector((state) => state.accounts.get(accountId));

  const handleClick = useCallback(() => {
    if (partOfAntenna) {
      const api = isExclude
        ? apiRemoveExcludeAccountFromAntenna
        : apiRemoveAccountFromAntenna;
      void api(antennaId, accountId);
    } else {
      const api = isExclude
        ? apiAddExcludeAccountToAntenna
        : apiAddAccountToAntenna;
      void api(antennaId, accountId);
    }

    onToggle(accountId);
  }, [accountId, antennaId, partOfAntenna, onToggle, isExclude]);

  if (!account) {
    return null;
  }

  const firstVerifiedField = account.fields.find((item) => !!item.verified_at);

  return (
    <div className='account'>
      <div className='account__wrapper'>
        <Link
          key={account.id}
          className='account__display-name'
          title={account.acct}
          to={`/@${account.acct}`}
          data-hover-card-account={account.id}
        >
          <div className='account__avatar-wrapper'>
            <Avatar account={account} size={36} />
          </div>

          <div className='account__contents'>
            <DisplayName account={account} />

            <div className='account__details'>
              <ShortNumber
                value={account.followers_count}
                renderer={FollowersCounter}
                isHide={account.other_settings.hide_followers_count}
              />{' '}
              {firstVerifiedField && (
                <VerifiedBadge link={firstVerifiedField.value} />
              )}
            </div>
          </div>
        </Link>

        <div className='account__relationship'>
          <Button
            text={intl.formatMessage(
              partOfAntenna ? messages.remove : messages.add,
            )}
            onClick={handleClick}
          />
        </div>
      </div>
    </div>
  );
};

const AntennaMembers: React.FC<{
  isExclude?: boolean;
  multiColumn?: boolean;
}> = ({ isExclude, multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id: string }>();
  const intl = useIntl();

  const [searching, setSearching] = useState(false);
  const [accountIds, setAccountIds] = useState<string[]>([]);
  const [searchAccountIds, setSearchAccountIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(!!id);
  const [mode, setMode] = useState<Mode>('remove');

  useEffect(() => {
    if (id) {
      dispatch(fetchAntenna(id));

      const api = isExclude ? apiGetExcludeAccounts : apiGetAccounts;
      void api(id)
        .then((data) => {
          dispatch(importFetchedAccounts(data));
          setAccountIds(data.map((a) => a.id));
          setLoading(false);
          return '';
        })
        .catch(() => {
          setLoading(false);
        });

      dispatch(fetchFollowing(me));
    }
  }, [dispatch, id, isExclude]);

  const handleSearchClick = useCallback(() => {
    setMode('add');
  }, [setMode]);

  const handleDismissSearchClick = useCallback(() => {
    setMode('remove');
    setSearching(false);
  }, [setMode]);

  const handleAccountToggle = useCallback(
    (accountId: string) => {
      const partOfAntenna = accountIds.includes(accountId);

      if (partOfAntenna) {
        setAccountIds(accountIds.filter((id) => id !== accountId));
      } else {
        setAccountIds([accountId, ...accountIds]);
      }
    },
    [accountIds, setAccountIds],
  );

  const searchRequestRef = useRef<AbortController | null>(null);

  const handleSearch = useDebouncedCallback(
    (value: string) => {
      if (searchRequestRef.current) {
        searchRequestRef.current.abort();
      }

      if (value.trim().length === 0) {
        setSearching(false);
        return;
      }

      setLoading(true);

      searchRequestRef.current = new AbortController();

      void apiRequest<ApiAccountJSON[]>('GET', 'v1/accounts/search', {
        signal: searchRequestRef.current.signal,
        params: {
          q: value,
          resolve: false,
        },
      })
        .then((data) => {
          dispatch(importFetchedAccounts(data));
          setSearchAccountIds(data.map((a) => a.id));
          setLoading(false);
          setSearching(true);
          return '';
        })
        .catch(() => {
          setSearching(true);
          setLoading(false);
        });
    },
    500,
    { leading: true, trailing: true },
  );

  let displayedAccountIds: string[];

  if (mode === 'add') {
    displayedAccountIds = searching ? searchAccountIds : accountIds;
  } else {
    displayedAccountIds = accountIds;
  }

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(messages.heading)}
    >
      {mode === 'remove' ? (
        <ColumnHeader
          title={intl.formatMessage(messages.heading)}
          icon='antenna-ul'
          iconComponent={AntennaIcon}
          multiColumn={multiColumn}
          showBackButton
          extraButton={
            <button
              onClick={handleSearchClick}
              type='button'
              className='column-header__button'
              title={intl.formatMessage(messages.enterSearch)}
              aria-label={intl.formatMessage(messages.enterSearch)}
            >
              <Icon id='plus' icon={AddIcon} />
            </button>
          }
        />
      ) : (
        <ColumnSearchHeader
          onBack={handleDismissSearchClick}
          onSubmit={handleSearch}
        />
      )}

      <ScrollableList
        scrollKey='antenna_members'
        trackScroll={!multiColumn}
        bindToDocument={!multiColumn}
        isLoading={loading}
        showLoading={loading && displayedAccountIds.length === 0}
        hasMore={false}
        footer={
          mode === 'remove' && (
            <>
              {displayedAccountIds.length > 0 && <div className='spacer' />}

              <div className='column-footer'>
                <Link
                  to={`/antennas/${id}/filtering`}
                  className='button button--block'
                >
                  <FormattedMessage id='antennas.done' defaultMessage='Done' />
                </Link>
              </div>
            </>
          )
        }
        emptyMessage={
          mode === 'remove' ? (
            <>
              <span>
                <FormattedMessage
                  id='antennas.no_members_yet'
                  defaultMessage='No members yet.'
                />
                <br />
                <FormattedMessage
                  id='antennas.find_users_to_add'
                  defaultMessage='Find users to add'
                />
              </span>

              <SquigglyArrow className='empty-column-indicator__arrow' />
            </>
          ) : (
            <FormattedMessage
              id='antennas.no_results_found'
              defaultMessage='No results found.'
            />
          )
        }
      >
        {displayedAccountIds.map((accountId) => (
          <AccountItem
            key={accountId}
            accountId={accountId}
            antennaId={id}
            partOfAntenna={
              displayedAccountIds === accountIds ||
              accountIds.includes(accountId)
            }
            isExclude={isExclude}
            onToggle={handleAccountToggle}
          />
        ))}
      </ScrollableList>

      <Helmet>
        <title>{intl.formatMessage(messages.heading)}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default AntennaMembers;
