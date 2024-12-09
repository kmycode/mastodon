import { useCallback, useState, useEffect } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';
import { useParams, useHistory } from 'react-router-dom';

import { isFulfilled } from '@reduxjs/toolkit';

import BookmarkIcon from '@/material-icons/400-24px/bookmark-fill.svg?react';
import { fetchBookmarkCategory } from 'mastodon/actions/bookmark_categories';
import {
  createBookmarkCategory,
  updateBookmarkCategory,
} from 'mastodon/actions/bookmark_categories_typed';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  edit: {
    id: 'column.edit_bookmark_category',
    defaultMessage: 'Edit bookmark_category',
  },
  create: {
    id: 'column.create_bookmark_category',
    defaultMessage: 'Create bookmark_category',
  },
});

const NewBookmarkCategory: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id?: string }>();
  const intl = useIntl();
  const history = useHistory();

  const bookmark_category = useAppSelector((state) =>
    id ? state.bookmark_categories.get(id) : undefined,
  );
  const [title, setTitle] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (id) {
      dispatch(fetchBookmarkCategory(id));
    }
  }, [dispatch, id]);

  useEffect(() => {
    if (id && bookmark_category) {
      setTitle(bookmark_category.title);
    }
  }, [setTitle, id, bookmark_category]);

  const handleTitleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleSubmit = useCallback(() => {
    setSubmitting(true);

    if (id) {
      void dispatch(
        updateBookmarkCategory({
          id,
          title,
        }),
      ).then(() => {
        setSubmitting(false);
        return '';
      });
    } else {
      void dispatch(
        createBookmarkCategory({
          title,
        }),
      ).then((result) => {
        setSubmitting(false);

        if (isFulfilled(result)) {
          history.replace(`/bookmark_categories/${result.payload.id}/edit`);
          history.push(`/bookmark_categories`);
        }

        return '';
      });
    }
  }, [history, dispatch, setSubmitting, id, title]);

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(id ? messages.edit : messages.create)}
    >
      <ColumnHeader
        title={intl.formatMessage(id ? messages.edit : messages.create)}
        icon='bookmark_category-ul'
        iconComponent={BookmarkIcon}
        multiColumn={multiColumn}
        showBackButton
      />

      <div className='scrollable'>
        <form className='simple_form app-form' onSubmit={handleSubmit}>
          <div className='fields-group'>
            <div className='input with_label'>
              <div className='label_input'>
                <label htmlFor='bookmark_category_title'>
                  <FormattedMessage
                    id='bookmark_categories.bookmark_category_name'
                    defaultMessage='BookmarkCategory name'
                  />
                </label>

                <div className='label_input__wrapper'>
                  <input
                    id='bookmark_category_title'
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

          <div className='actions'>
            <button className='button' type='submit'>
              {submitting ? (
                <LoadingIndicator />
              ) : id ? (
                <FormattedMessage
                  id='bookmark_categories.save'
                  defaultMessage='Save'
                />
              ) : (
                <FormattedMessage
                  id='bookmark_categories.create'
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
export default NewBookmarkCategory;
