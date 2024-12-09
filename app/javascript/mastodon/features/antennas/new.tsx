import { useCallback, useState, useEffect } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';
import { useParams, useHistory, Link } from 'react-router-dom';

import { isFulfilled } from '@reduxjs/toolkit';

import Toggle from 'react-toggle';

import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { fetchAntenna } from 'mastodon/actions/antennas';
import { createAntenna, updateAntenna } from 'mastodon/actions/antennas_typed';
import { fetchLists } from 'mastodon/actions/lists';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import { getOrderedLists } from 'mastodon/selectors/lists';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  edit: { id: 'column.edit_antenna', defaultMessage: 'Edit antenna' },
  create: { id: 'column.create_antenna', defaultMessage: 'Create antenna' },
});

const FiltersLink: React.FC<{
  id: string;
}> = ({ id }) => {
  return (
    <Link to={`/antennas/${id}/filtering`} className='app-form__link'>
      <div className='app-form__link__text'>
        <strong>
          <FormattedMessage
            id='antennas.filter_items'
            defaultMessage='Move to antenna filter setting'
          />
        </strong>
      </div>
    </Link>
  );
};

const NewAntenna: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id?: string }>();
  const intl = useIntl();
  const history = useHistory();

  const antenna = useAppSelector((state) =>
    id ? state.antennas.get(id) : undefined,
  );
  const lists = useAppSelector((state) => getOrderedLists(state));
  const [title, setTitle] = useState('');
  const [stl, setStl] = useState(false);
  const [ltl, setLtl] = useState(false);
  const [insertFeeds, setInsertFeeds] = useState(false);
  const [listId, setListId] = useState('');
  const [withMediaOnly, setWithMediaOnly] = useState(false);
  const [ignoreReblog, setIgnoreReblog] = useState(false);
  const [mode, setMode] = useState('filtering');
  const [destination, setDestination] = useState('timeline');
  const [favourite, setFavourite] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (id) {
      dispatch(fetchAntenna(id));
      dispatch(fetchLists());
    }
  }, [dispatch, id]);

  useEffect(() => {
    if (id && antenna) {
      setTitle(antenna.title);
      setStl(antenna.stl);
      setLtl(antenna.ltl);
      setInsertFeeds(antenna.insert_feeds);
      setListId(antenna.list?.id ?? '0');
      setWithMediaOnly(antenna.with_media_only);
      setIgnoreReblog(antenna.ignore_reblog);
      setFavourite(antenna.favourite);

      if (antenna.stl) {
        setMode('stl');
      } else if (antenna.ltl) {
        setMode('ltl');
      } else {
        setMode('filtering');
      }

      if (antenna.insert_feeds) {
        if (antenna.list) {
          setDestination('list');
        } else {
          setDestination('home');
        }
      } else {
        setDestination('timeline');
      }
    }
  }, [
    setTitle,
    setStl,
    setLtl,
    setInsertFeeds,
    setListId,
    setWithMediaOnly,
    setIgnoreReblog,
    setMode,
    setDestination,
    setFavourite,
    id,
    antenna,
    lists,
  ]);

  const handleTitleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleListIdChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLSelectElement>) => {
      setListId(value);
    },
    [setListId],
  );

  const handleModeChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLSelectElement>) => {
      if (value === 'stl') {
        setStl(true);
        setLtl(false);
      } else if (value === 'ltl') {
        setStl(false);
        setLtl(true);
      } else if (value === 'filtering') {
        setStl(false);
        setLtl(false);
      }

      setMode(value);
    },
    [setLtl, setStl, setMode],
  );

  const handleDestinationChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLSelectElement>) => {
      if (value === 'list') {
        setInsertFeeds(true);
        if (listId === '0' && lists.length > 0) {
          setListId(lists[0]?.id ?? '0');
        }
      } else if (value === 'home') {
        setInsertFeeds(true);
        // listId = 0
      } else if (value === 'timeline') {
        setInsertFeeds(false);
      }

      setDestination(value);
    },
    [setDestination, setListId, listId, lists],
  );

  const handleWithMediaOnlyChange = useCallback(
    ({ target: { checked } }: React.ChangeEvent<HTMLInputElement>) => {
      setWithMediaOnly(checked);
    },
    [setWithMediaOnly],
  );

  const handleIgnoreReblogChange = useCallback(
    ({ target: { checked } }: React.ChangeEvent<HTMLInputElement>) => {
      setIgnoreReblog(checked);
    },
    [setIgnoreReblog],
  );

  const handleFavouriteChange = useCallback(
    ({ target: { checked } }: React.ChangeEvent<HTMLInputElement>) => {
      setFavourite(checked);
    },
    [setFavourite],
  );

  const handleSubmit = useCallback(() => {
    setSubmitting(true);

    if (id) {
      void dispatch(
        updateAntenna({
          id,
          title,
          stl,
          ltl,
          insert_feeds: insertFeeds,
          list_id: destination === 'list' ? listId : '0',
          with_media_only: withMediaOnly,
          ignore_reblog: ignoreReblog,
          favourite,
        }),
      ).then(() => {
        setSubmitting(false);
        return '';
      });
    } else {
      void dispatch(
        createAntenna({
          title,
          stl,
          ltl,
          insert_feeds: insertFeeds,
          list_id: destination === 'list' ? listId : '0',
          with_media_only: withMediaOnly,
          ignore_reblog: ignoreReblog,
          favourite,
        }),
      ).then((result) => {
        setSubmitting(false);

        if (isFulfilled(result)) {
          history.replace(`/antennas/${result.payload.id}/edit`);
          history.push(`/antennas/${result.payload.id}/members`);
        }

        return '';
      });
    }
  }, [
    history,
    dispatch,
    setSubmitting,
    id,
    title,
    stl,
    ltl,
    insertFeeds,
    listId,
    withMediaOnly,
    ignoreReblog,
    destination,
    favourite,
  ]);

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(id ? messages.edit : messages.create)}
    >
      <ColumnHeader
        title={intl.formatMessage(id ? messages.edit : messages.create)}
        icon='antenna-ul'
        iconComponent={AntennaIcon}
        multiColumn={multiColumn}
        showBackButton
      />

      <div className='scrollable'>
        <form className='simple_form app-form' onSubmit={handleSubmit}>
          <div className='fields-group'>
            <div className='input with_label'>
              <div className='label_input'>
                <label htmlFor='antenna_title'>
                  <FormattedMessage
                    id='antennas.antenna_name'
                    defaultMessage='Antenna name'
                  />
                </label>

                <div className='label_input__wrapper'>
                  <input
                    id='antenna_title'
                    type='text'
                    value={title}
                    onChange={handleTitleChange}
                    maxLength={30}
                    required
                    placeholder=' '
                  />
                </div>
              </div>
            </div>
          </div>

          <div className='fields-group'>
            <div className='input with_label'>
              <div className='label_input'>
                <label htmlFor='antenna_list'>
                  <FormattedMessage id='antennas.mode' defaultMessage='Mode' />
                </label>

                <div className='label_input__wrapper'>
                  <select
                    id='antenna_insert_list'
                    value={mode}
                    onChange={handleModeChange}
                  >
                    <FormattedMessage
                      id='antennas.mode.stl'
                      defaultMessage='Social timeline mode'
                    >
                      {(msg) => <option value='stl'>{msg}</option>}
                    </FormattedMessage>
                    <FormattedMessage
                      id='antennas.mode.ltl'
                      defaultMessage='Local timeline mode'
                    >
                      {(msg) => <option value='ltl'>{msg}</option>}
                    </FormattedMessage>
                    <FormattedMessage
                      id='antennas.mode.filtering'
                      defaultMessage='Filtering'
                    >
                      {(msg) => <option value='filtering'>{msg}</option>}
                    </FormattedMessage>
                  </select>
                </div>
              </div>
            </div>
          </div>

          <div className='fields-group'>
            <div className='input with_label'>
              <div className='label_input'>
                <label htmlFor='antenna_list'>
                  <FormattedMessage
                    id='antennas.destination'
                    defaultMessage='Destination'
                  />
                </label>

                <div className='label_input__wrapper'>
                  <select
                    id='antenna_insert_destination'
                    value={destination}
                    onChange={handleDestinationChange}
                  >
                    <FormattedMessage
                      id='antennas.destination.home'
                      defaultMessage='Insert to home'
                    >
                      {(msg) => <option value='home'>{msg}</option>}
                    </FormattedMessage>
                    <FormattedMessage
                      id='antennas.destination.list'
                      defaultMessage='Insert to list'
                    >
                      {(msg) => <option value='list'>{msg}</option>}
                    </FormattedMessage>
                    <FormattedMessage
                      id='antennas.destination.timeline'
                      defaultMessage='Antenna timeline only'
                    >
                      {(msg) => <option value='timeline'>{msg}</option>}
                    </FormattedMessage>
                  </select>
                </div>
              </div>
            </div>
          </div>

          {destination === 'list' && (
            <div className='fields-group'>
              <div className='input with_label'>
                <div className='label_input'>
                  <label htmlFor='antenna_list'>
                    <FormattedMessage
                      id='antennas.list_selection'
                      defaultMessage='List to insert'
                    />
                  </label>

                  <div className='label_input__wrapper'>
                    <select
                      id='antenna_insert_list'
                      value={listId}
                      onChange={handleListIdChange}
                    >
                      {lists.map((list) => (
                        <option key={list.id} value={list.id}>
                          {list.title}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
            </div>
          )}

          {id && mode === 'filtering' && (
            <div className='fields-group'>
              <FiltersLink id={id} />
            </div>
          )}

          {!id && mode === 'filtering' && (
            <div className='fields-group'>
              <div className='app-form__memo'>
                <FormattedMessage
                  id='antennas.save_to_edit_filtering'
                  defaultMessage='You can edit the filtering after saving.'
                />
              </div>
            </div>
          )}

          {mode === 'filtering' && (
            <>
              <div className='fields-group'>
                {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
                <label className='app-form__toggle'>
                  <div className='app-form__toggle__label'>
                    <strong>
                      <FormattedMessage
                        id='antennas.media_only'
                        defaultMessage='Media only'
                      />
                    </strong>
                    <span className='hint'>
                      <FormattedMessage
                        id='antennas.media_only_hint'
                        defaultMessage='Only posts with media will be added antenna.'
                      />
                    </span>
                  </div>

                  <div className='app-form__toggle__toggle'>
                    <div>
                      <Toggle
                        checked={withMediaOnly}
                        onChange={handleWithMediaOnlyChange}
                      />
                    </div>
                  </div>
                </label>
              </div>

              <div className='fields-group'>
                {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
                <label className='app-form__toggle'>
                  <div className='app-form__toggle__label'>
                    <strong>
                      <FormattedMessage
                        id='antennas.ignore_reblog'
                        defaultMessage='Exclude boosts'
                      />
                    </strong>
                    <span className='hint'>
                      <FormattedMessage
                        id='antennas.ignore_reblog_hint'
                        defaultMessage='Boosts will be excluded from antenna detection.'
                      />
                    </span>
                  </div>

                  <div className='app-form__toggle__toggle'>
                    <div>
                      <Toggle
                        checked={ignoreReblog}
                        onChange={handleIgnoreReblogChange}
                      />
                    </div>
                  </div>
                </label>
              </div>
            </>
          )}

          <div className='fields-group'>
            {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
            <label className='app-form__toggle'>
              <div className='app-form__toggle__label'>
                <strong>
                  <FormattedMessage
                    id='antennas.favourite'
                    defaultMessage='Favorite'
                  />
                </strong>
                <span className='hint'>
                  <FormattedMessage
                    id='antennas.favourite_hint'
                    defaultMessage='When opening the Web Client on a PC, this antenna appears in the navigation.'
                  />
                </span>
              </div>

              <div className='app-form__toggle__toggle'>
                <div>
                  <Toggle
                    checked={favourite}
                    onChange={handleFavouriteChange}
                  />
                </div>
              </div>
            </label>
          </div>

          <div className='actions'>
            <button className='button' type='submit'>
              {submitting ? (
                <LoadingIndicator />
              ) : id ? (
                <FormattedMessage id='antennas.save' defaultMessage='Save' />
              ) : (
                <FormattedMessage
                  id='antennas.create'
                  defaultMessage='Create'
                />
              )}
            </button>
          </div>
        </form>
      </div>

      <Helmet>
        <title>
          {intl.formatMessage(id ? messages.edit : messages.create)}
        </title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default NewAntenna;
